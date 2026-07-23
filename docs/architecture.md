# Architecture

## Overview

The application uses a small layered Flutter architecture:

```text
UI screens and widgets
        ↓
AdventureController
        ↓
Repository interfaces
        ↓
SQLite reference data + SQLite user data
```

## Main directories

| Path | Responsibility |
| --- | --- |
| `lib/ui/` | screens, navigation, and presentation |
| `lib/ui/widgets/` | reusable Pokémon and type widgets |
| `lib/application/` | application state and orchestration |
| `lib/domain/` | immutable models, battle rules, and repository contracts |
| `lib/data/` | SQLite repositories, content activation, and update seam |
| `assets/content/` | bundled reference database and manifest |
| `assets/artwork/` | base-species artwork |
| `assets/form_artwork/` | displayed-form artwork |
| `tool/` | separated snapshot acquisition, validation, and offline generation |
| `test/` | model, repository, persistence, and widget tests |

## Runtime data flow

1. `ContentStorage` reads the bundled manifest.
2. A newer bundled database is copied into app-private support storage.
3. `SqliteReferenceRepository` opens that copied database read-only.
4. `SqliteUserRepository` opens a separate writable trainer database.
5. `AdventureController` loads both repositories and exposes state to widgets.
6. Collection changes are written to the user database before the controller
   publishes the new in-memory state.

Reference-data upgrades therefore do not overwrite trainer progress.

## Reference storage

The bundled manifest contains a monotonically increasing `datasetVersion`.
`ContentStorage` compares it with the active pointer:

```text
assets/content/demo_manifest.json
                ↓
app support/content/active-pointer.json
                ↓
app support/content/slot-a/reference.sqlite
```

Only bundled local activation is currently implemented. The pointer is written
through an adjacent temporary file, but activation is not transactional as a
whole: the implementation always writes `slot-a` and can overwrite the active
database before the pointer changes. It does not validate the copied database,
retain a previous slot, recover a malformed pointer, or roll back after an
interrupted copy.

The slot/pointer concept remains the seam for future verified updates. It must
gain immutable candidate slots, validation, atomic activation, retained
rollback content, and startup recovery before downloaded content uses it.

Content preparation currently happens before `runApp`. A preparation failure
therefore cannot be displayed by the Flutter error view.

## Build-time reference-data flow

Reference-data tooling is isolated from the Flutter runtime:

```text
PokeAPI + legacy cache + existing artwork
                 ↓ explicit acquisition only
ignored immutable source snapshot + tracked lock
                 ↓ validated, socket-blocked generation
ignored candidate + checksums/reports/comparison
                 ↓ separate future review and promotion
bundled assets/content + artwork
```

`tool/acquire_reference_snapshot.py` is the only network-capable entry point.
`tool/build_reference_data.py` validates one locked snapshot, blocks socket
connections, creates output in a temporary directory, validates SQLite and
artwork, then atomically publishes a candidate under `build/`. It never changes
the active bundled database or artwork. The runtime content activation design
is unchanged by this build-time pipeline.

## Domain models

`PokemonSpecies` contains:

- identity and National Pokédex number
- description and measurements
- generation, types, and abilities
- base stats and moves
- forms and evolution links

`PokemonForm` includes its own types, category, note, battle-only flag, and
artwork asset path.

Type effectiveness lives in `lib/domain/battle/type_matchups.dart`. It combines
both defending types, including 4× weaknesses, ¼× resistances, and immunities.

## UI navigation

`AdventureShell` keeps four primary destinations alive in an `IndexedStack`:

- Home
- Pokédex
- Collection
- Let’s Go Gyms

Phones use `NavigationBar`; wider layouts use `NavigationRail`.

Each Gym expansion tile has a unique `PageStorageKey`. Helper choices use
wrapping, natural-height layouts rather than nested horizontal scroll lists.

The fixed Gym roster facts remain in the UI model.
`GymRecommendationService` in the application layer calculates
opponent-specific effective move types and deterministic helper rankings. It
uses the shared `isLetsGoSpecies` domain predicate, which also powers the
Pokédex scope. Caught recommendations require a matching move in the bundled
data. Uncaught recommendations additionally require a condition-free
`overworld` or `overworld-special` record whose reviewed `requiredBadges` value
is lower than the viewed Gym number. Gifts, trades, traversal methods, static
or conditioned encounters, and later progression are rejected fail-closed.
`GymGuideScreen` listens to the controller so returning from a Collection
change refreshes suggestions without restarting the app.

The independently versioned `assets/guides/lets_go_encounters.json` asset is
read through `EncounterGuideRepository`. `AdventureController` loads it only
after core reference and trainer readiness. Load or validation failure exposes
an empty guide without setting the app error, preserving caught-only guidance
and offline startup.

`AdventureController` owns a per-species pending-write set for collection
changes. Screens route favorite, status, and automatic Seen writes through one
failure-handling path. The repository is called first; only a successful write
changes published collection state.
