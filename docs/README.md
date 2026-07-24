# Documentation

## Guides

- [Product guide](product-guide.md) — screens, behavior, and child-friendly
  battle guidance
- [Architecture](architecture.md) — application layers, storage, and data flow
- [Data and artwork](data-and-assets.md) — dataset contents, regeneration, and
  provenance
- [Development](development.md) — setup, tests, builds, emulator workflow, and
  troubleshooting
- [Homelab app updates](homelab-updates.md) — private APK update manifest,
  checksum verification, Android confirmation, and publishing workflow
- [Implementation status](implementation-status.md) — verified repository
  facts, known risks, and next-phase boundaries

## Current snapshot

| Item | Count |
| --- | ---: |
| Species | 1,025 |
| Displayed forms | 200 |
| Evolution links | 484 |
| Move-learning links | 68,736 |
| Base artwork files | 1,025 |
| Form artwork files | 200 |
| Bundled dataset version | 4 |

The app is Android-first, works offline, and is intended for private family
use. It can optionally check a private HTTPS homelab for signed APK updates.
The permanent family signing chain is established; future releases must use
the same keystore and an increasing Android version code.
