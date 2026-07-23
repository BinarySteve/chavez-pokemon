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
- all eight Let’s Go story Gym teams with move-aware suggestions
- local trainer profile, favorites, Seen, Caught, Shiny, and Want to Find
- 1,225 bundled images and no runtime internet requirement

## Quick start

```powershell
flutter pub get
flutter test
flutter run
```

The checked-in database and artwork are the runnable application inputs. The
current legacy data tool can rebuild them, but it combines acquisition and
generation, may contact PokeAPI for missing cache entries or artwork, and is
not deterministic:

```powershell
python tool\build_lets_go_data.py
```

Run that command only when intentionally replacing generated content. It writes
the bundled reference database directly. The planned pipeline will separate
network acquisition from an offline deterministic build.

The generated reference database is stored at
`assets/content/demo_reference.sqlite`. The filename is retained from the
original prototype; it now contains the full dataset.

## Documentation

- [Documentation index](docs/README.md)
- [Product guide](docs/product-guide.md)
- [Architecture](docs/architecture.md)
- [Data and artwork pipeline](docs/data-and-assets.md)
- [Development and testing](docs/development.md)
- [Implementation status](docs/implementation-status.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Current release status

The application is functional for private family use, but release engineering
is not complete. Android release builds currently use the debug signing
certificate. The bundled content activator has no validated rollback slot, and
the data generator is not yet a frozen offline pipeline. See the
[implementation status](docs/implementation-status.md) before preparing an
update or family-device release.

## Distribution warning

Pokémon artwork is copyright The Pokémon Company and its licensors. It is
bundled only for this private family application. Do not publish or redistribute
the APK or artwork without a separate rights review.
