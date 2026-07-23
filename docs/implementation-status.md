# Implementation status

Verified against the repository on 2026-07-23.

## Working private-family application

- Flutter 3.44.4 and Dart 3.12.2 match package constraints.
- Static analysis passes and all 17 automated tests pass.
- Android release APK builds successfully at about 199 MB.
- Package identifier is `com.chavezfamily.pokemon_adventure`.
- Minimum Android SDK is 24; target and compile SDK are 36.
- Release manifest requests no internet, storage, location, analytics, or
  advertising permissions.
- Reference and trainer data use separate SQLite files.
- Reference database opens read-only and collection changes write only to the
  trainer database.
- Home, Pokédex, Collection, Let’s Go Gym guide, onboarding, detail pages,
  local artwork, adaptive navigation, and basic accessibility behavior work.

## Verified bundled snapshot

| Item | Verified value |
| --- | ---: |
| Dataset version | 4 |
| Content schema | 1 |
| Species | 1,025 |
| Displayed forms | 200 |
| Evolution links | 484 |
| Move-learning links | 68,736 |
| Base artwork files | 1,025 |
| Form artwork files | 200 |
| Reference DB SHA-256 | `35a5cffc50f115ba1c80d860be43ec9ec8a12a248a186b2e61f1b96247170319` |

SQLite `integrity_check` returns `ok`; `foreign_key_check` returns no rows.
Every artwork file has a PNG signature. The current PokeAPI cache contains
every structured response required by the legacy generator, but it is not a
sealed or immutable source snapshot.

## Known technical limits

- `ContentStorage` copies only to `slot-a`. It never uses a retained rollback
  slot.
- A newer bundled database overwrites the active file before pointer
  replacement. Activation is therefore not transactional as a whole.
- Copied content receives no runtime hash, SQLite, schema, semantic, or asset
  validation.
- Malformed pointers and missing active files have no automatic recovery.
- Content preparation runs before `runApp`, so its failures cannot reach the
  friendly Flutter error screen.
- `BundledUpdateService` compares only the bundled manifest. It does not
  download or activate content.
- Trainer database has schema version 1 but no explicit upgrade or downgrade
  migration callbacks.
- Collection state changes optimistically before the database write succeeds.
- Gym helper candidates are not yet restricted to Pokémon available in
  Let’s Go.
- Startup and search performance have no representative-device budget.

## Data-pipeline limits

`tool/build_lets_go_data.py` is a legacy combined acquisition/build command:

- cache misses trigger live network requests;
- existing artwork is accepted without a checksum;
- cached responses can come from different acquisition times;
- output metadata includes the current build time;
- the shipping database is replaced directly before final validation; and
- no source manifest records completeness, checksums, upstream revision,
  attribution bundle, or immutable snapshot identity.

The command is useful for the current private workspace but is not a
deterministic release pipeline. The former `tool/generate_demo_db.dart`
prototype was removed because it could overwrite the shipping database with an
obsolete, runtime-incompatible schema.

## Release and distribution limits

- Android `release` currently uses the debug signing certificate.
- No permanent keystore injection, backup, certificate record, release
  runbook, or release-over-release installation test exists.
- Changing from a debug certificate to a permanent certificate requires
  preserving trainer data before reinstalling.
- Public distribution is not approved. Pokémon names, designs, and artwork
  require a separate rights review.
- Full third-party notices must travel with any binary distribution.

## Next implementation boundary

Next code phase corrects current child-guidance and persistence behavior.
Deterministic data acquisition/build, schema hardening, transactional content
activation, homelab updates, and permanent APK signing remain separate later
phases. Do not combine them into one migration.
