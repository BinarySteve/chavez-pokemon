# Data and artwork

## Sources

Structured species, form, evolution, type, stat, ability, and move data comes
from [PokeAPI](https://pokeapi.co/). The build tool caches raw responses in
`third_party/pokeapi-cache/`.

Base and form artwork is downloaded from URLs exposed by PokeAPI. See
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) for licensing and
distribution restrictions.

Let’s Go Gym roster facts were checked against Pokémon Database. The app stores
only factual team data; it does not bundle article prose or website images.

## Generated snapshot

The current dataset contains:

- 1,025 species
- 200 meaningful forms
- 484 evolution links
- 68,736 move-learning links
- 1,025 base artwork files
- 200 form artwork files

The generator discovers the current species catalog from PokeAPI instead of
hard-coding a maximum National Pokédex number.

## Current legacy pipeline

The current command combines network acquisition and output generation:

Run:

```powershell
python tool\build_lets_go_data.py
```

The tool:

1. downloads and caches the species catalog
2. fetches default Pokémon and species records concurrently
3. selects meaningful regional, Mega, Gigantamax, and special forms
4. caches move, form, and evolution metadata
5. downloads missing base and form artwork
6. translates evolution requirements into readable conditions
7. creates a fresh SQLite reference database
8. checks SQLite integrity and foreign keys

Cached responses and existing images make later runs much faster. Cache misses
and missing artwork make live network requests. Existing artwork is trusted
without a checksum, cache entries can represent different acquisition times,
and generated metadata includes the build clock. The command is therefore not
a deterministic offline release build.

The tool writes `assets/content/demo_reference.sqlite` directly. Do not run it
as a routine app build step. Preserve the current generated database before an
intentional data refresh.

`tool/generate_demo_db.dart` was an early miniature fixture generator. It was
removed because its schema no longer matched the runtime repository and it
could overwrite the full shipping database.

## Planned reproducible pipeline

Future data work will split the current tool:

- `tool/acquire_reference_snapshot.py` will be the only network-capable step.
- `tool/build_reference_content.py` will consume one complete, checksummed
  local snapshot and will make no network requests.
- acquisition will record source details, acquisition time, upstream revision
  or API metadata when available, licenses, attribution, and file checksums;
- generation will validate completeness before writing temporary outputs;
- generation will publish only after SQLite, foreign-key, semantic, artwork,
  and checksum validation; and
- the same snapshot and tool version will produce the same logical content.

Exact snapshot and manifest wire formats are intentionally deferred to that
implementation phase.

## Move selection

- Let’s Go-compatible species use the
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

Official artwork is preferred. If unavailable, the pipeline tries HOME artwork
and then the default front sprite. A base-species image is the final fallback.

## Evolution conditions

The generator handles conditions including:

- level
- friendship, affection, and Beauty
- time of day
- gender
- known move or known move type
- location
- held or used item
- weather
- party species or party type
- relative Attack and Defense
- upside-down system orientation
- trade target

Alternative valid conditions are joined with “or.”

## SQLite tables

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
Those are targeted schema-hardening work, not reasons to replace SQLite or the
existing layered architecture.

## Updating the bundled snapshot

After changing the generated data or schema:

1. preserve the current known-good database and artwork
2. deliberately run the legacy generator, allowing network access if cache
   inputs are missing
3. increment `dataset_version` in the generator
4. increment `datasetVersion` in `assets/content/demo_manifest.json`
5. update snapshot counts and the recorded database checksum
6. run repository and widget tests
7. verify SQLite integrity, foreign keys, manifest/metadata agreement, and
   artwork counts before accepting outputs

The manifest version must increase so existing installations activate the new
bundled database.
