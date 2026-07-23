# Product guide

Pokémon Adventure is designed as a calm companion a child can use beside a
Pokémon game. It does not require an account, email address, or internet
connection after installation.

## Main areas

### Home

- greets the local trainer
- shows the selected partner
- tracks Seen, Caught, and Favorite totals
- suggests a Pokémon to discover
- rotates a Pokémon of the day

### Pokédex

The Pokédex supports:

- search by name, form name, or National Pokédex number
- forgiving one-character typo matching
- All Pokémon and Let’s Go scopes
- type and generation filters
- collection filters for Favorites, Seen, Caught, Shiny, and Want to Find

The **Let’s Go** scope contains National Pokédex numbers 1–151 plus Meltan
and Melmetal.

### Pokémon details

Each species page can show:

- official artwork and National Pokédex number
- types, classification, description, height, and weight
- base stats and abilities
- collection controls
- evolution routes and conditions
- meaningful forms
- game-relevant moves
- kid-friendly battle matchups

Every displayed form has local artwork. Tapping a form opens a large detail
sheet with its artwork, types, category, notes, and battle-only status.

### Kid-friendly battle guidance

The battle card is written from the perspective of fighting the displayed
Pokémon:

- **Best choices** — “Amazing! 4×” or “Strong! 2×”
- **Not very helpful** — “Weak” or “Very weak”
- **Won’t work** — no damage because of a type immunity

The card reminds the child to check the move’s type, not only the attacking
Pokémon’s type. Level, stats, and the selected move still matter.

### Collection

Collection state is stored locally and separately from reference data. A child
can mark a species as:

- Seen
- Caught
- Favorite
- Shiny
- Want to Find

The app waits for the local trainer database to save a change before updating
the control. While that species is saving, its collection controls are
disabled. If the write fails, the last saved values remain visible and the app
offers a retry.

### Let’s Go Gyms

The Gym guide covers the first story battle for all eight Let’s Go Gyms. Each
entry separates guidance by opposing Pokémon and includes:

- leader, city, specialty, and badge
- opponent team and levels
- useful attacking move types with their actual effectiveness multipliers
- up to eight Let’s Go-compatible Pokémon that contain a relevant move in the
  bundled move data

Gym recommendations are guidance, not guaranteed wins. Team level, stats, and
the moves currently equipped still matter. A helper tile identifies matching
move types, not an equipped move set.

Recommendations are restricted to the Let’s Go-compatible species roster:
National Pokédex numbers 1–151, Meltan, and Melmetal. This is a compatibility
filter, not a guarantee that a helper is available at the current story
progression point or exclusive to the child’s game version.

## Interaction and accessibility

- tapping outside an input dismisses keyboard focus
- layouts adapt between phone navigation bars and tablet navigation rails
- onboarding, Pokédex, Collection, expanded Gym guidance, Pokémon details, and
  form sheets are tested at 200% text scale on phone and tablet viewports
- lists and helper choices use natural-height or wrapping layouts at large text
- artwork and controls include semantic labels
- collection and form controls use large touch targets
- theme controls and type badges maintain at least 4.5:1 text contrast
