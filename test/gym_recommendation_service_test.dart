import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/application/gym_recommendation_service.dart';
import 'package:pokemon_adventure/domain/lets_go_species.dart';
import 'package:pokemon_adventure/domain/models/encounter_guide.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';

void main() {
  const service = GymRecommendationService();

  test('Let’s Go roster has exact National Dex boundaries', () {
    expect(isLetsGoSpecies(0), isFalse);
    expect(isLetsGoSpecies(1), isTrue);
    expect(isLetsGoSpecies(151), isTrue);
    expect(isLetsGoSpecies(152), isFalse);
    expect(isLetsGoSpecies(808), isTrue);
    expect(isLetsGoSpecies(809), isTrue);
    expect(isLetsGoSpecies(810), isFalse);
  });

  test('caught recommendations require a matching move and game roster', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
        _pokemon(54, 'Psyduck', ['Water']),
        _pokemon(906, 'Sprigatito', ['Grass'], moveTypes: ['Grass']),
      ],
      caught: const {7, 54, 906},
    );

    expect(advice.caughtHelpers.map((item) => item.pokemon.name), ['Squirtle']);
    expect(advice.caughtHelpers.single.bestMultiplier, 4);
  });

  test('4× and useful-type ranking stays deterministic', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
        _pokemon(1, 'Bulbasaur', ['Grass'], moveTypes: ['Grass']),
        _pokemon(9, 'Blastoise', ['Water'], moveTypes: ['Water', 'Ice']),
      ],
      caught: const {1, 7, 9},
    );

    expect(advice.moveTypes.take(2).map((item) => item.type), [
      'Grass',
      'Water',
    ]);
    expect(advice.caughtHelpers.map((item) => item.pokemon.dexNumber), [
      9,
      1,
      7,
    ]);
  });

  test('immunities and resisted moves are rejected', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(
          151,
          'Mew',
          ['Psychic'],
          moveTypes: ['Electric', 'Fire', 'Water'],
        ),
      ],
      caught: const {151},
    );

    expect(advice.caughtHelpers.single.moveTypes.map((item) => item.type), [
      'Water',
    ]);
  });

  test('caught and catch limits are enforced', () {
    final candidates = [
      for (var id = 1; id <= 12; id++)
        _pokemon(id, 'Helper $id', ['Grass'], moveTypes: ['Grass']),
    ];
    final advice = _recommend(
      service,
      candidates: candidates,
      caught: {1, 2, 3, 4, 5},
      guide: _guide([
        for (var id = 6; id <= 12; id++) _encounter(id, areaId: 1),
      ]),
    );

    expect(advice.caughtHelpers, hasLength(4));
    expect(advice.catchSuggestions, hasLength(3));
    expect(advice.catchSuggestions.map((item) => item.pokemon.id), [6, 7, 8]);
  });

  test('caught helpers come first and are not suggested for catching', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(1, 'Bulbasaur', ['Grass'], moveTypes: ['Grass']),
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
      ],
      caught: const {1},
      guide: _guide([_encounter(1, areaId: 1), _encounter(7, areaId: 1)]),
    );

    expect(advice.caughtHelpers.single.pokemon.name, 'Bulbasaur');
    expect(advice.catchSuggestions.single.pokemon.name, 'Squirtle');
  });

  test('encounters at or after the Gym and postgame are excluded', () {
    final candidates = [
      _pokemon(1, 'Before', ['Grass'], moveTypes: ['Grass']),
      _pokemon(2, 'At Gym', ['Grass'], moveTypes: ['Grass']),
      _pokemon(3, 'After', ['Grass'], moveTypes: ['Grass']),
    ];
    final guide = _guide(
      [
        _encounter(1, areaId: 1),
        _encounter(2, areaId: 2),
        _encounter(3, areaId: 3),
      ],
      badges: const {1: 0, 2: 1, 3: 8},
    );

    final advice = _recommend(service, candidates: candidates, guide: guide);
    expect(advice.catchSuggestions.map((item) => item.pokemon.name), [
      'Before',
    ]);
  });

  test('normal walking ranks above rare and both games above exclusive', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(1, 'Rare', ['Grass'], moveTypes: ['Grass']),
        _pokemon(2, 'Exclusive', ['Grass'], moveTypes: ['Grass']),
        _pokemon(3, 'Both', ['Grass'], moveTypes: ['Grass']),
      ],
      guide: _guide([
        _encounter(1, areaId: 1, method: 'overworld-special'),
        _encounter(2, areaId: 1, versions: const [LetsGoVersion.pikachu]),
        _encounter(3, areaId: 1),
      ]),
    );

    expect(advice.catchSuggestions.map((item) => item.pokemon.name), [
      'Both',
      'Exclusive',
      'Rare',
    ]);
    expect(
      advice.catchSuggestions.first.locations.single.versionLabel,
      'Both games',
    );
    expect(
      advice.catchSuggestions[1].locations.single.versionLabel,
      'Pikachu version',
    );
  });

  test('unsupported and conditioned encounters are excluded', () {
    final methods = ['gift', 'trade', 'surf', 'sky', 'static'];
    final candidates = [
      for (var index = 0; index < methods.length + 1; index++)
        _pokemon(index + 1, 'Helper $index', ['Grass'], moveTypes: ['Grass']),
    ];
    final guide = _guide([
      for (var index = 0; index < methods.length; index++)
        _encounter(index + 1, areaId: 1, method: methods[index]),
      _encounter(6, areaId: 1, conditions: const ['time-day']),
    ]);

    final advice = _recommend(service, candidates: candidates, guide: guide);
    expect(advice.catchSuggestions, isEmpty);
  });

  test('missing guide degrades to caught-only advice', () {
    final advice = _recommend(
      service,
      candidates: [
        _pokemon(1, 'Bulbasaur', ['Grass'], moveTypes: ['Grass']),
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
      ],
      caught: const {1},
    );
    expect(advice.caughtHelpers.single.pokemon.name, 'Bulbasaur');
    expect(advice.catchSuggestions, isEmpty);
  });
}

GymOpponentAdvice _recommend(
  GymRecommendationService service, {
  required List<PokemonSpecies> candidates,
  Set<int> caught = const {},
  EncounterGuide guide = EncounterGuide.empty,
}) {
  return service.recommendForOpponent(
    opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
    candidates: candidates,
    caughtSpeciesIds: caught,
    encounterGuide: guide,
    gymBadgeNumber: 1,
  );
}

EncounterGuide _guide(
  List<LetsGoEncounter> encounters, {
  Map<int, int> badges = const {1: 0},
}) {
  return EncounterGuide(
    guideSchemaVersion: 1,
    guideVersion: 1,
    logicalSha256: 'a' * 64,
    areas: {
      for (final entry in badges.entries)
        entry.key: LetsGoEncounterArea(
          id: entry.key,
          displayName: 'Area ${entry.key}',
          requiredBadges: entry.value,
        ),
    },
    encounters: encounters,
  );
}

LetsGoEncounter _encounter(
  int speciesId, {
  required int areaId,
  String method = 'overworld',
  List<LetsGoVersion> versions = const [
    LetsGoVersion.pikachu,
    LetsGoVersion.eevee,
  ],
  List<String> conditions = const [],
}) {
  return LetsGoEncounter(
    speciesId: speciesId,
    areaId: areaId,
    versions: versions,
    method: method,
    minLevel: 3,
    maxLevel: 6,
    slotRarity: 10,
    conditions: conditions,
  );
}

PokemonSpecies _pokemon(
  int id,
  String name,
  List<String> types, {
  List<String> moveTypes = const [],
}) {
  return PokemonSpecies(
    id: id,
    dexNumber: id,
    name: name,
    classification: 'Fixture Pokémon',
    description: 'Fixture',
    heightMeters: 1,
    weightKilograms: 1,
    generation: 1,
    types: types,
    abilities: const [],
    forms: const [],
    evolutionEdges: const [],
    moves: [
      for (final type in moveTypes)
        PokemonMove(
          name: '$type move',
          type: type,
          learnMethod: 'level-up',
          levelLearned: 1,
        ),
    ],
  );
}
