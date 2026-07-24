# Development and testing

## Prerequisites

- Flutter 3.44 or compatible
- Dart 3.12 or compatible
- Python 3.13 or compatible for dataset generation
- Android SDK, ADB, and an emulator or Android device

## Install dependencies

```powershell
flutter pub get
```

## Run locally

List devices:

```powershell
flutter devices
```

Run on the selected emulator:

```powershell
flutter run
```

## Validation

Format Dart source:

```powershell
dart format lib test
```

Run static analysis:

```powershell
flutter analyze
```

Run all tests:

```powershell
flutter test
python -m unittest discover -s tool\tests -v
```

Current coverage includes:

- search normalization and typo matching
- type effectiveness, dual-type multiplication, and immunity
- bundled manifest/database metadata agreement and semantic counts
- reference-database SQLite integrity and foreign keys
- form artwork existence
- user profile and collection persistence
- persistence-first collection writes, failure preservation, and duplicate
  pending-write suppression
- onboarding and adaptive navigation
- All Pokémon and Let’s Go scope switching
- tap-outside keyboard dismissal
- opponent-isolated Gym recommendation ranking, Let’s Go roster exclusion,
  Caught-state filtering, move requirements, multipliers, and caught/catch
  caps
- pre-Gym progression exclusion, walking-method and condition filtering,
  normal-versus-rare ranking, version labels, and missing-guide fallback
- audited encounter-guide asset coverage and malformed-guide rejection
- Gym helper rendering, catch locations/levels/version labels, live Caught
  refresh, and the no-matching-helper fallback
- kid-friendly matchup labels
- theme and type-badge contrast plus focused semantic labels
- 200% text scaling on phone and tablet for onboarding, Pokédex, Collection,
  expanded Gyms, Pokémon details, form sheets, mini adventures, and the
  Sticker Scrapbook
- trainer schema 1-to-2 migration, non-destructive downgrade rejection,
  migration rollback, atomic/idempotent activity completion, and sticker
  persistence
- deterministic daily activities, Free Play variation, Collection
  personalization, unambiguous choices, gentle correction, save retry, daily
  replay, local-date rollover, and orphaned sticker rendering
- Android detail-route back and modal-sheet back behavior

Not yet covered:

- transactional content activation, interrupted copies, rollback, or recovery
- trainer-database backup or restore
- release-over-release installation and signing identity
- representative-device startup and search performance

## Build Android APK

```powershell
flutter build apk --debug
```

The debug APK is large because 1,225 artwork files are bundled for offline use.

A release APK also builds, but `android/app/build.gradle.kts` currently signs
the release build with the Android debug certificate. Do not treat that APK as
the permanent family-device release identity. Establish and back up a
permanent release key before a durable update chain begins.

Install and launch on the current emulator:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am force-stop com.chavezfamily.pokemon_adventure
adb shell monkey -p com.chavezfamily.pokemon_adventure `
  -c android.intent.category.LAUNCHER 1
```

## Validate and generate reference-data candidates

```powershell
python tool\build_reference_data.py validate-snapshot
python tool\build_reference_data.py build --allow-snapshot-warnings
python tool\build_reference_data.py validate-output `
  --output build\reference-data\2026-07-23-pokeapi-r2
python tool\build_reference_data.py build-guide
python tool\build_reference_data.py validate-guide `
  --guide build\reference-data\2026-07-23-pokeapi-r2\lets_go_encounters.json
```

The build command is offline by construction and publishes only to ignored
candidate output under `build/reference-data/`. It does not modify shipping
assets. The current snapshot warnings describe the lack of a PokeAPI immutable
revision and the mixed-age legacy cache; review them before passing
`--allow-snapshot-warnings`.

Inspect counts and the previous-dataset comparison:

```powershell
Get-Content build\reference-data\2026-07-23-pokeapi-r2\reports\semantic_counts.json
Get-Content build\reference-data\2026-07-23-pokeapi-r2\reports\comparison.md
```

No network setup is needed for generation: the command installs an in-process
socket guard and fails if transformation code attempts a connection.

To acquire a new immutable species/artwork snapshot, use
`tool/acquire_reference_snapshot.py`. To extend a restored r1 snapshot with
the pinned encounter CSV source, use `tool/acquire_encounter_snapshot.py`.
These are the only network-capable reference-data commands. See
[Data and artwork](data-and-assets.md) for the full acquisition, archive,
recovery, and promotion workflow.

`tool/build_lets_go_data.py` is deprecated and delegates only to offline
generation. Routine Flutter builds and tests do not require regeneration.

## Common problems

### Installed app still shows old content

Confirm both dataset versions were incremented:

- generator metadata `dataset_version`
- manifest `datasetVersion`

Then rebuild and reinstall the APK.

### SQLite file is locked on Windows

Stop the stale Flutter debug or data-generator process, then rerun generation.
Do not delete trainer data from the emulator.

### Locked source snapshot is missing

Read `third_party/source_snapshot.lock.json`, restore the matching immutable
directory from the private homelab artifact store or second backup into
`third_party/source_snapshots/`, then rerun `validate-snapshot`. Do not rebuild
from the mutable cache merely to bypass a missing archive.

### Gym tab shows a type-cast error

Keep unique `PageStorageKey` values on each Gym `ExpansionTile`. Do not reuse a
Gym expansion key for another saved scroll or expansion state.

### Artwork does not appear

Check that:

- the asset exists under `assets/artwork/` or `assets/form_artwork/`
- the path stored in the `forms.artwork_asset` column is correct
- both asset directories remain declared in `pubspec.yaml`

## Distribution

This repository is configured with `publish_to: none`. Keep the application and
artwork private unless a separate legal and rights review permits distribution.
Include the complete notices in `THIRD_PARTY_NOTICES.md` with any binary shared
outside the development machine.
