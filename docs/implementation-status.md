# Implementation status

Verified against the repository on 2026-07-23.

## Completed phase: progress-aware Gym recommendations

Purpose: lead with Pokémon the child already owns, then offer a small,
conservative set of useful Pokémon she can encounter before the viewed Gym.

Implemented behavior:

- an independently versioned bundled guide contains 65 reviewed areas and 737
  grouped Let’s Go encounter records covering 130 directly encountered roster
  species;
- each opponent shows up to four matching Caught helpers, followed by up to
  three uncaught pre-Gym walking suggestions;
- catch suggestions include matching move types, up to two locations, level
  ranges, Rare spawn labels, and explicit Both games/Pikachu/Eevee labels;
- ranking is deterministic and prioritizes effectiveness, normal walking
  encounters, both-game availability, useful move variety, and National Dex
  number;
- only condition-free `overworld` and `overworld-special` records are eligible,
  and an area must have `requiredBadges` lower than the viewed Gym number; and
- guide loading is nonblocking and fail-safe: missing or malformed guide data
  keeps caught-only advice available.

Boundary: this is conservative Let’s Go-compatible guidance, not a guarantee
of exact story progression or version availability. It intentionally excludes
gifts, trades, water, flying, static, conditioned, fossil, transfer, and
evolution-only paths until their prerequisites are structured.

Compatibility:

- dataset version 4, content schema 1, trainer schema 1, reference database,
  content manifest, and 1,225 artwork files are unchanged;
- the guide has its own schema version 1 and guide version 1; and
- no runtime network access or trainer migration is added.

Completion evidence:

- all 44 Flutter tests and all 24 pipeline tests pass;
- Flutter analysis reports no issues;
- snapshot r2 and the bundled guide validate against their pinned hashes and
  audited counts; and
- the Android debug APK builds successfully.

## Completed phase: child-guidance correctness

Purpose: keep current child-facing Gym advice within the Let’s Go roster, make
collection writes truthful when storage fails, and protect important layouts
and labels at large text.

Implemented behavior:

- one shared Let’s Go predicate covers species 1–151, 808, and 809 for both
  Pokédex filtering and Gym helpers;
- `GymRecommendationService` calculates advice separately for every opponent,
  reports actual effective-move multipliers, requires both Caught state and a
  matching move, and ranks at most eight helpers deterministically;
- the destination and screen are named “Let’s Go Gyms,” and helper cards name
  their opponent and useful move type;
- the guide separates best move types from other helpful choices, labels
  recommendations “Your caught helpers,” and gives a reassuring move-type
  fallback instead of suggesting an uncaught Pokémon;
- collection changes are persistence-first, with per-species pending state,
  disabled controls during writes, unchanged saved state on failure, and a
  retry action;
- primary theme controls and type badges choose foreground colors that meet
  the 4.5:1 text-contrast threshold;
- targeted semantics remove duplicate spoken artwork, badge, progress, and
  count labels; and
- onboarding, Pokédex, Collection, Gym helpers, Pokémon details, and form
  sheets use wrapping or natural-height layouts under large text.

Compatibility:

- dataset version remains 4 and content schema remains 1;
- the trainer database remains schema version 1 with no migration;
- bundled databases, manifests, and artwork are unchanged; and
- navigation keeps the existing four destinations.

Recommendation boundary at completion of that phase was caught-only. The
progress-aware phase above adds separately versioned encounter guidance without
changing reference schema 1.

Completion evidence:

- Dart formatting is unchanged and Flutter analysis reports no issues;
- the child-guidance phase’s original tests remain part of the 44 passing
  Flutter tests, including domain, controller, widget,
  accessibility, large-text, route-back, and modal-back coverage;
- all 24 reference-pipeline tests and the production snapshot/output
  validators pass;
- the Android debug APK builds successfully;
- the bundled reference DB and manifest retain SHA-256 values
  `35a5cffc50f115ba1c80d860be43ec9ec8a12a248a186b2e61f1b96247170319`
  and
  `4c25cf025f3517ff2330e6aede7c6550a295213e6c0b9784c3db4f3df88b1546`;
  and
- 1,025 base and 200 form artwork files remain present, with no diff to
  bundled content, artwork, or trainer-schema code.

## Completed phase: frozen reference-data pipeline

Purpose: separate network acquisition from deterministic reference-data
generation while preserving the installed Flutter application and current
bundled dataset.

Previous behavior:

- `tool/build_lets_go_data.py` mixes PokeAPI acquisition, mutable cache reads,
  artwork downloading, transformations, SQLite generation, and direct output
  replacement;
- cache entries are named from URL paths and query strings, usually retaining
  endpoint and numeric stable IDs, but have no snapshot-wide completeness or
  checksum contract;
- missing cache entries trigger HTTP requests;
- malformed or truncated cached JSON fails when parsed, while stale but
  parseable responses are accepted without age or revision checks;
- existing artwork is accepted by filename without an integrity check; and
- current cache plus artwork is complete enough to reproduce the shipping
  semantic data without networking.

Implemented behavior:

- network access exists only in an explicit acquisition command;
- acquisition writes and validates an incomplete temporary directory before
  promoting one immutable, versioned source snapshot;
- snapshot metadata inventories and hashes every required record and artwork
  file;
- deterministic generation validates an explicit snapshot, blocks network
  access, writes temporary outputs, validates them, and only then publishes a
  candidate output directory;
- generated reports record provenance, checksums, semantic counts, and
  comparisons; and
- a failed acquisition or generation never replaces a finalized snapshot or
  existing generated output.

Expected repository changes:

- Python acquisition, snapshot-validation, deterministic-generation, and
  reporting modules under `tool/`;
- small Python test fixtures and tests;
- a source-snapshot lock/provenance record;
- `.gitignore`, README, data/development documentation, and generator
  references; and
- generated candidate reports under ignored build output during validation.

Must not change:

- `assets/content/demo_reference.sqlite`;
- `assets/content/demo_manifest.json`;
- `assets/artwork/` and `assets/form_artwork/`;
- Flutter runtime, navigation, UI, controller, repository, or trainer-storage
  behavior; and
- dataset version 4 or content schema 1.

Compatibility risks:

- transformation drift could change semantic rows even when counts remain
  equal;
- a mixed-age legacy cache can be sealed only with an explicit review warning;
- physical SQLite bytes can vary across SQLite versions even when ordered
  logical rows match; and
- generated metadata gains provenance fields, so a candidate database can
  differ from the active database without requiring a dataset-version increase
  when displayed content remains identical.

Validation:

- Python unit and integration tests with small snapshots;
- independent production-snapshot validation;
- deterministic generation while socket access is blocked;
- generated SQLite integrity and foreign-key checks;
- semantic counts and artwork mappings;
- table-level logical comparison with the active database;
- Dart formatting, Flutter analysis and tests; and
- Android debug build.

Exit criteria:

- complete snapshots can be explicitly acquired, independently validated, and
  archived outside Git;
- missing/corrupt required files fail clearly;
- offline generation succeeds from a complete snapshot;
- repeated builds have stable logical output;
- failed builds preserve existing output;
- generated metadata identifies source snapshot and generator;
- current production semantic counts remain unchanged; and
- active bundled content and trainer data remain untouched.

Completion evidence:

- snapshot `2026-07-23-pokeapi-r1` validates with 4,814 declared source files,
  including 1,025 species records, 1,025 default Pokémon records, 200 form
  records, 795 move records, 541 evolution chains, and 1,225 artwork mappings;
- its tracked lock records metadata SHA-256
  `e4ed549a1f79d3596ce4ee392a4f391766d754fe1c0716e43a27ae1354a579e2`;
- the production-sized candidate builds with network access blocked;
- generated SQLite integrity and foreign-key checks pass;
- all eight content-table hashes match the active bundled database, with
  logical SHA-256
  `9ed71871e2fd31e00196f3fcc0f49ac4c7e8435e83989b309ae8c99568ab4160`;
- repeated production and fixture builds produce the same logical database;
  both were also byte-identical on the verified Windows/SQLite toolchain;
- malformed, missing, corrupt, incomplete, and duplicate-ID fixtures fail;
- failed generation preserves an existing output; and
- the shipping reference database remains SHA-256
  `35a5cffc50f115ba1c80d860be43ec9ec8a12a248a186b2e61f1b96247170319`.

## Working private-family application

- Flutter 3.44.4 and Dart 3.12.2 match package constraints.
- Static analysis and the expanded automated test suites pass.
- Android release APK builds successfully at about 199 MB.
- Package identifier is `com.chavezfamily.pokemon_adventure`.
- Minimum Android SDK is 24; target and compile SDK are 36.
- Release manifest requests no internet, storage, location, analytics, or
  advertising permissions.
- Reference and trainer data use separate SQLite files.
- Reference database opens read-only and collection changes write only to the
  trainer database.
- Home, Pokédex, Collection, Let’s Go Gyms, onboarding, detail pages, local
  artwork, adaptive navigation, and tested large-text/accessibility behavior
  work.

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
- Startup and search performance have no representative-device budget.

## Data-pipeline limits

- PokeAPI's live API exposes no immutable upstream revision for the sealed
  legacy inputs.
- Legacy cache files may have different original acquisition times. This is a
  recorded, explicit-acceptance warning.
- The full immutable snapshot is too large for Git and must still be copied to
  the homelab artifact store and a second backup.
- Logical output is deterministic for a snapshot/tool version. Physical SQLite
  bytes are not promised across different SQLite library versions.
- Candidate promotion into shipping assets is deliberately absent.
- Current schema 1 still omits hidden-ability, move-version, description-source,
  upstream-form-ID, and structured-evolution metadata.

`tool/build_lets_go_data.py` is now a deprecated offline wrapper.
`tool/generate_demo_db.dart` remains removed.

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

Next code phase is targeted reference-schema hardening after the frozen
pipeline. Transactional content activation, homelab updates, and permanent APK
signing remain separate later phases. Do not combine them into one migration.
