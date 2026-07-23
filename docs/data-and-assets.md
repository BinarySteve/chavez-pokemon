# Data and artwork

## Sources

Structured species, form, evolution, type, stat, ability, and move data comes
from [PokeAPI](https://pokeapi.co/). Network acquisition caches raw responses
in `third_party/pokeapi-cache/`, but that mutable cache is not a build input
after a snapshot is sealed.

Let’s Go encounter records come from the official PokéAPI repository CSV data
pinned to commit
`091f3a0599b1efb01f6b502232eeb7d8cbbb3e8f`. The guide retains both game
versions, location areas, encounter methods, levels, slot rarity, and condition
identifiers. Runtime Gym suggestions deliberately use only condition-free
walking encounters.

Base and form artwork comes from URLs exposed by PokeAPI. See
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) for licensing and
distribution restrictions.

Let's Go Gym roster facts were checked against Pokémon Database. The app stores
only factual team data; it does not bundle article prose or website images.

## Shipping dataset

The checked-in, runnable application inputs remain unchanged:

- 1,025 species
- 200 meaningful forms
- 484 evolution links
- 68,736 move-learning links
- 1,025 base artwork files
- 200 form artwork files
- dataset version 4 and content schema 1
- encounter guide schema 1 with 65 areas, 737 grouped encounter records, and
  130 directly encountered Let’s Go species

Acquisition discovers the current species catalog from PokeAPI instead of
hard-coding a maximum National Pokédex number.

## Pipeline responsibilities

The pipeline has three strict responsibilities:

- `tool/acquire_reference_snapshot.py` may use HTTPS. It gathers records and
  artwork into a unique incomplete directory, writes provenance and per-file
  SHA-256 values, validates completeness, and only then renames the directory
  to its immutable snapshot ID.
- `tool/acquire_encounter_snapshot.py` may use HTTPS only to extend a complete
  immutable snapshot with the exact encounter CSV dependency set from the
  pinned PokéAPI Git commit. It creates a new snapshot ID and never edits its
  parent.
- `tool/build_reference_data.py validate-snapshot` independently checks the
  snapshot format, completion marker, file sizes and hashes, JSON parsing,
  stable IDs, expected counts, required species/evolutions/types, artwork
  mappings, and PNG signatures.
- `tool/build_reference_data.py build` performs transformations with socket
  connections blocked. It writes a temporary candidate, validates SQLite
  integrity, foreign keys, tables, metadata, semantic counts, artwork, and
  checksums, then atomically publishes the candidate under
  `build/reference-data/`.
- `tool/build_reference_data.py build-guide` performs the encounter
  transformation with sockets blocked and emits a deterministic, independently
  versioned JSON guide.

Generation never writes `assets/content/`, `assets/artwork/`, or
`assets/form_artwork/`. Candidate promotion is a separate, deliberate content
release operation and is not implemented by this phase.

`tool/build_lets_go_data.py` is a deprecated wrapper for the offline build
command. It exists to fail safely for old operator habits; it has no acquisition
logic and does not write shipping assets. The obsolete miniature
`tool/generate_demo_db.dart` was removed because its schema did not match the
runtime repository.

## Snapshot contract and storage

A finalized snapshot is one directory whose name equals `snapshotId`. It
contains:

- `snapshot.json` with format/tool versions, source provenance, acquisition
  times, known omissions, language scope, record indexes, expected counts,
  critical records, licenses, artwork mappings, and a complete file manifest;
- `.complete`, which binds the finalized directory to the metadata SHA-256;
- structured source records under `records/`;
- source artwork under `artwork/`;
- `mappings/artwork.json`; and
- the attribution bundle under `licenses/`.

Finalized snapshot directories are ignored by Git. The tracked
`third_party/source_snapshot.lock.json` selects the default snapshot and records
its metadata hash and expected counts. The canonical full snapshot must be
copied to the private homelab artifact store and a second independent backup.
Do not edit a finalized snapshot. Acquire a new ID instead.

The current lock selects `2026-07-23-pokeapi-r2`. It preserves every validated
r1 input and adds 13 encounter CSV files from the pinned PokéAPI commit. The
r1 parent remains immutable. PokeAPI’s live species inputs still lack an
immutable upstream revision and may have mixed acquisition times; the encounter
CSV extension itself has an exact Git revision.

## Operator workflow

Restore the snapshot selected by the lock into
`third_party/source_snapshots/<snapshot-id>/`, then validate:

```powershell
python tool\build_reference_data.py validate-snapshot
python tool\build_reference_data.py report-snapshot
```

Both validation commands refresh machine-readable JSON and human-readable
Markdown under
`build/reference-data/snapshot-reports/<snapshot-id>/`.

Build the locked snapshot offline:

```powershell
python tool\build_reference_data.py build --allow-snapshot-warnings
python tool\build_reference_data.py validate-output `
  --output build\reference-data\2026-07-23-pokeapi-r2
python tool\build_reference_data.py build-guide
python tool\build_reference_data.py validate-guide `
  --guide build\reference-data\2026-07-23-pokeapi-r2\lets_go_encounters.json
```

The warnings flag is required for the current mixed-age legacy snapshot.
Review the report before using it. The default build compares every ordered
content table with `assets/content/demo_reference.sqlite` and writes comparison
JSON and Markdown under the candidate's `reports/` directory.

To recreate the encounter-extended snapshot from an externally restored r1:

```powershell
python tool\acquire_encounter_snapshot.py `
  --snapshot-id 2026-07-23-pokeapi-r2
```

This command is intentionally network-capable. It accepts no moving branch or
version input; the repository commit is fixed in the acquisition module.

To seal another snapshot from the current cache without network:

```powershell
python tool\acquire_reference_snapshot.py `
  --snapshot-id <new-immutable-id> `
  --cache-only `
  --source-acquired-at-utc <known-UTC-time> `
  --accept-warnings `
  --write-lock third_party\source_snapshot.lock.json
```

Omit `--cache-only` only when intentionally acquiring from PokeAPI. A missing
or malformed cache entry fails in cache-only mode. A finalized snapshot ID is
never overwritten. Failed acquisition leaves an unmistakably named incomplete
directory for inspection; remove it only after confirming whether a valid
final snapshot with that ID exists.

If a build fails, the incomplete candidate is removed and any existing output
directory remains intact. Use `--replace-output` only after reviewing the
target. Publishing uses an adjacent backup and restores it if replacement
fails.

## Move selection

- Let's Go-compatible species use the
  `lets-go-pikachu-lets-go-eevee` version group when available.
- Other species use their latest available PokeAPI version-group detail.
- Move availability is therefore representative of the selected source game,
  not a promise that every listed move exists in every Pokémon title.

## Forms

The app currently displays forms categorized as:

- Alolan, Galarian, Hisuian, and Paldean regional forms
- Mega Evolutions
- Gigantamax forms
- selected Origin and Therian forms

Official artwork is preferred. If unavailable, acquisition tries HOME artwork
and then the default front sprite. A base-species image is the final fallback.

## Evolution conditions

The transformation handles level, friendship, affection, Beauty, time of day,
gender, known moves and move types, location, held or used items, weather,
party species/types, relative Attack and Defense, upside-down orientation, and
trade targets. Alternative valid conditions are joined with “or.”

## SQLite tables and current limits

Generated candidates contain:

- `metadata`
- `species`
- `species_types`
- `species_abilities`
- `species_stats`
- `species_moves`
- `forms`
- `form_types`
- `evolution_edges`

This schema supports the current displayed experience. It does not retain
hidden-ability flags, move version groups, description language/version
provenance, numeric upstream form IDs, or structured evolution requirements.
Those remain targeted schema-hardening work, not reasons to replace SQLite or
the existing layered architecture.

`assets/guides/lets_go_encounters.json` is not a SQLite schema extension. It is
a separately versioned bundled guide, so dataset version 4, content schema 1,
and trainer schema 1 remain unchanged. Its logical hash excludes no source
fields and is verified before promotion.

## Candidate review and future promotion

This phase intentionally does not promote generated output. Before any later
promotion into bundled assets:

1. review snapshot and generation warnings;
2. inspect `reports/comparison.json` for logical changes;
3. verify the snapshot exists in both external backup locations;
4. choose dataset/content-schema versions according to compatibility;
5. run Python, Flutter, SQLite, artwork, and Android build validation; and
6. use the future explicit promotion/runbook path, retaining previous bundled
   content for rollback.

Lower dataset versions must never replace higher ones. Equal versions are a
no-op unless a future repair path proves active content invalid. A content
schema change requires an app version that declares support for it. Current
shipping content remains dataset version 4 and schema 1.

Increase `datasetVersion` when intentionally promoted logical content changes:
added or corrected species/form facts, moves, evolutions, artwork mappings, or
other runtime-visible reference data. Rebuilding the same logical content,
changing reports, or changing provenance fields alone does not justify an
increase.

Increase `contentSchema` when tables, columns, constraints, value meaning, or
required asset contracts change in a way readers must understand. A
transformation-tool change that leaves schema and logical rows unchanged is
recorded by `generatorVersion` and repository revision only. Never change
either shipping version until a candidate is deliberately promoted.

Bundled-content activation remains the current runtime `ContentStorage`
slot/pointer behavior documented in [Architecture](architecture.md). Future
homelab delivery will transport and verify candidates; it is not part of
acquisition, generation, or this phase.
