import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/application/gym_recommendation_service.dart';
import 'package:pokemon_adventure/domain/lets_go_species.dart';
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

  test(
    'recommendations require matching moves and reject out-of-game species',
    () {
      final advice = service.recommendForOpponent(
        opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
        caughtSpeciesIds: const {7, 25, 54, 906},
        candidates: [
          _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
          _pokemon(25, 'Pikachu', ['Electric'], moveTypes: ['Electric']),
          _pokemon(54, 'Psyduck', ['Water']),
          _pokemon(906, 'Sprigatito', ['Grass'], moveTypes: ['Grass']),
        ],
      );

      expect(advice.helpers.map((helper) => helper.pokemon.name), ['Squirtle']);
      expect(advice.helpers.single.moveTypes.single.type, 'Water');
      expect(advice.helpers.single.bestMultiplier, 4);
    },
  );

  test('dual-type advice ranks 4× types before 2× types deterministically', () {
    final advice = service.recommendForOpponent(
      opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
      caughtSpeciesIds: const {1, 7, 9},
      candidates: [
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
        _pokemon(1, 'Bulbasaur', ['Grass'], moveTypes: ['Grass']),
        _pokemon(9, 'Blastoise', ['Water'], moveTypes: ['Water', 'Ice']),
      ],
    );

    expect(advice.moveTypes.take(2).map((item) => item.type), [
      'Grass',
      'Water',
    ]);
    expect(advice.moveTypes.take(2).map((item) => item.multiplier), [4, 4]);
    expect(advice.helpers.map((helper) => helper.pokemon.dexNumber), [9, 1, 7]);
  });

  test('immunities and resisted move types never become recommendations', () {
    final advice = service.recommendForOpponent(
      opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
      caughtSpeciesIds: const {151},
      candidates: [
        _pokemon(
          151,
          'Mew',
          ['Psychic'],
          moveTypes: ['Electric', 'Fire', 'Water'],
        ),
      ],
    );

    expect(advice.helpers.single.moveTypes.map((item) => item.type), ['Water']);
  });

  test('helper limit and opponent advice are isolated', () {
    final candidates = [
      for (var id = 1; id <= 12; id++)
        _pokemon(id, 'Helper $id', ['Grass'], moveTypes: ['Grass']),
      _pokemon(25, 'Pikachu', ['Electric'], moveTypes: ['Electric']),
    ];
    final rockAdvice = service.recommendForOpponent(
      opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
      candidates: candidates,
      caughtSpeciesIds: {for (final candidate in candidates) candidate.id},
      limit: 8,
    );
    final waterAdvice = service.recommendForOpponent(
      opponent: _pokemon(121, 'Starmie', ['Water', 'Psychic']),
      candidates: candidates,
      caughtSpeciesIds: {for (final candidate in candidates) candidate.id},
      limit: 20,
    );

    expect(rockAdvice.helpers, hasLength(8));
    expect(rockAdvice.helpers.map((helper) => helper.pokemon.dexNumber), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(
      waterAdvice.helpers.map((helper) => helper.pokemon.name),
      contains('Pikachu'),
    );
    expect(
      waterAdvice.helpers
          .firstWhere((helper) => helper.pokemon.name == 'Pikachu')
          .moveTypes
          .single
          .type,
      'Electric',
    );
  });

  test('uncaught matching Pokémon are never recommended', () {
    final advice = service.recommendForOpponent(
      opponent: _pokemon(95, 'Onix', ['Rock', 'Ground']),
      candidates: [
        _pokemon(1, 'Bulbasaur', ['Grass'], moveTypes: ['Grass']),
        _pokemon(7, 'Squirtle', ['Water'], moveTypes: ['Water']),
      ],
      caughtSpeciesIds: const {1},
    );

    expect(advice.helpers.map((helper) => helper.pokemon.name), ['Bulbasaur']);
  });
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
