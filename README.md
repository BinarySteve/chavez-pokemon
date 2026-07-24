# Pokémon Adventure

Private, offline-first Flutter companion for exploring the National Pokédex and
getting kid-friendly help with **Pokémon: Let’s Go, Pikachu!** and
**Pokémon: Let’s Go, Eevee!**

## What is included

- 1,025 National Pokédex species
- 200 regional, Mega, Gigantamax, and special forms with clickable artwork
- 484 evolution links with detailed evolution conditions
- 68,736 game-relevant move-learning links
- base stats, abilities, types, descriptions, height, and weight
- kid-friendly strength, weakness, resistance, and immunity guidance
- All Pokémon and Let’s Go Pokédex scopes
- all eight Let’s Go story Gym teams with opponent-specific caught helpers and
  pre-Gym walking encounter suggestions
- Adventure Camp with daily mini adventures, no-pressure Free Play, and a
  153-slot Sticker Scrapbook
- local trainer profile plus child-controlled Favorites, Seen, Caught, Shiny,
  and Want to Find tracking (browsing never marks a Pokémon Seen)
- searchable partner selection that can be changed anytime from Home
- optional homelab APK updates with a kid-friendly grown-up prompt, download
  progress, SHA-256 verification, and Android install confirmation
- 1,225 bundled images; internet is optional and used only for homelab updates

## Quick start

```powershell
flutter pub get
flutter test
flutter run
```

The checked-in database and artwork are the runnable application inputs.
Reference-data work is deliberately split into an explicit network-capable
acquisition step and a network-blocked generation step:

```powershell
python tool\acquire_reference_snapshot.py --snapshot-id <snapshot-id>
python tool\build_reference_data.py validate-snapshot
python tool\build_reference_data.py build
python tool\build_reference_data.py build-guide
```

Generation writes validated candidates under `build/reference-data/`; it does
not replace bundled database or artwork content. The current r2 source snapshot
preserves the sealed legacy species/artwork inputs and adds Let’s Go encounter
CSVs pinned to an exact PokéAPI repository commit. It is identified by
`third_party/source_snapshot.lock.json`; its large local directory is ignored
by Git and must be retained in the private homelab artifact store plus a second
backup.

`tool/build_lets_go_data.py` remains only as a deprecated compatibility wrapper
for the offline build command. It no longer acquires data or writes shipping
assets.

The generated reference database is stored at
`assets/content/demo_reference.sqlite`. The filename is retained from the
original prototype; it now contains the full dataset.

## Documentation

- [Documentation index](docs/README.md)
- [Product guide](docs/product-guide.md)
- [Architecture](docs/architecture.md)
- [Data and artwork pipeline](docs/data-and-assets.md)
- [Development and testing](docs/development.md)
- [Homelab app updates](docs/homelab-updates.md)
- [Implementation status](docs/implementation-status.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Current release status

The permanent family signing chain and private homelab update endpoint are
established. Family releases must keep using the existing keystore and must
increase the Android version code every time. Release builds still fall back to
the debug certificate when signing credentials are absent, but the combined
homelab release script rejects that certificate before publishing. Maintaining
encrypted, offline keystore backups remains essential. See
[Homelab app updates](docs/homelab-updates.md) for the repeatable release
workflow.

## Distribution warning

Pokémon artwork is copyright The Pokémon Company and its licensors. It is
bundled only for this private family application. Do not publish or redistribute
the APK or artwork without a separate rights review.
