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
```

Current coverage includes:

- search normalization and typo matching
- type effectiveness, dual-type multiplication, and immunity
- bundled manifest/database metadata agreement and semantic counts
- reference-database SQLite integrity and foreign keys
- form artwork existence
- user profile and collection persistence
- onboarding and adaptive navigation
- All Pokémon and Let’s Go scope switching
- tap-outside keyboard dismissal
- Gym helper rendering smoke coverage
- kid-friendly matchup labels
- 200% text scaling on the phone Home screen

Not yet covered:

- transactional content activation, interrupted copies, rollback, or recovery
- trainer-database migrations, backup, or restore
- collection write failures
- release-over-release installation and signing identity
- 200% layouts beyond Home
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

## Regenerate data

```powershell
python tool\build_lets_go_data.py
```

This legacy command uses the network for missing cache entries and artwork. It
is not deterministic and rebuilds `assets/content/demo_reference.sqlite`
directly. Preserve the current database before an intentional run. Routine
Flutter builds and tests do not require regeneration.

## Common problems

### Installed app still shows old content

Confirm both dataset versions were incremented:

- generator metadata `dataset_version`
- manifest `datasetVersion`

Then rebuild and reinstall the APK.

### SQLite file is locked on Windows

Stop the stale Flutter debug or data-generator process, then rerun generation.
Do not delete trainer data from the emulator.

### Gym tab shows a type-cast error

Keep unique `PageStorageKey` values on each Gym `ExpansionTile` and its nested
helper `ListView`. Reusing storage identity can mix a boolean expansion state
with a double scroll offset.

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
