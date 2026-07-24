import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/application/mini_adventure_service.dart';
import 'package:pokemon_adventure/domain/battle/type_matchups.dart';
import 'package:pokemon_adventure/domain/models/activity_progress.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/mini_adventure.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';

void main() {
  const service = MiniAdventureService();
  final species = _speciesFixture();

  test('daily adventure is deterministic for date and progress', () {
    final first = service.buildDaily(
      localDate: DateTime(2026, 7, 23, 8),
      species: species,
      collection: const {},
      partner: species.first,
      progress: ActivityProgress.empty,
    );
    final second = service.buildDaily(
      localDate: DateTime(2026, 7, 23, 22),
      species: species.reversed,
      collection: const {},
      partner: species.first,
      progress: ActivityProgress.empty,
    );

    expect(first.id, 'daily-v1-2026-07-23');
    expect(_signature(first), _signature(second));
  });

  test('daily reward scans to an unearned roster species', () {
    final unearned = species[4];
    final progress = ActivityProgress(
      completions: const {},
      earnedStickers: {
        for (final pokemon in species)
          if (pokemon.id != unearned.id)
            pokemon.id: EarnedSticker(
              speciesId: pokemon.id,
              sourceActivityId: 'old-${pokemon.id}',
              earnedAt: DateTime.utc(2026),
            ),
      },
    );

    final adventure = service.buildDaily(
      localDate: DateTime(2026, 7, 23),
      species: species,
      collection: const {},
      partner: species.first,
      progress: progress,
    );

    expect(adventure.reward?.id, unearned.id);
    expect(
      (adventure.rounds.first as PokemonGuessRound).target.id,
      unearned.id,
    );
  });

  test('completed scrapbook keeps adventures playable without reward', () {
    final progress = ActivityProgress(
      completions: const {},
      earnedStickers: {
        for (final pokemon in species)
          pokemon.id: EarnedSticker(
            speciesId: pokemon.id,
            sourceActivityId: 'old-${pokemon.id}',
            earnedAt: DateTime.utc(2026),
          ),
      },
    );

    final adventure = service.buildDaily(
      localDate: DateTime(2026, 7, 23),
      species: species,
      collection: const {},
      partner: species.first,
      progress: progress,
    );

    expect(adventure.reward, isNull);
    expect(adventure.rounds, hasLength(3));
  });

  test('completed daily adventure replays the same reward and questions', () {
    final first = service.buildDaily(
      localDate: DateTime(2026, 7, 23),
      species: species,
      collection: const {},
      partner: species.first,
      progress: ActivityProgress.empty,
    );
    final completion = ActivityCompletion(
      activityId: first.id,
      activityDate: first.activityDate,
      rewardSpeciesId: first.reward!.id,
      completedAt: DateTime.utc(2026, 7, 23, 12),
    );
    final progress = ActivityProgress(
      completions: {first.id: completion},
      earnedStickers: {
        first.reward!.id: EarnedSticker(
          speciesId: first.reward!.id,
          sourceActivityId: first.id,
          earnedAt: completion.completedAt,
        ),
      },
    );

    final replay = service.buildDaily(
      localDate: DateTime(2026, 7, 23, 23),
      species: species,
      collection: const {},
      partner: species.first,
      progress: progress,
    );
    final tomorrow = service.buildDaily(
      localDate: DateTime(2026, 7, 24),
      species: species,
      collection: const {},
      partner: species.first,
      progress: progress,
    );

    expect(_signature(replay), _signature(first));
    expect(tomorrow.id, isNot(first.id));
    expect(tomorrow.reward?.id, isNot(first.reward?.id));
  });

  test('rounds have three unique choices and one correct answer', () {
    final adventure = service.buildFreePlay(
      seed: 42,
      species: species,
      collection: const {},
      partner: species.first,
    );
    final guess = adventure.rounds[0] as PokemonGuessRound;
    final type = adventure.rounds[1] as TypePowerRound;
    final evolution = adventure.rounds[2] as EvolutionTrailRound;

    expect(guess.choices.map((item) => item.id).toSet(), hasLength(3));
    expect(
      guess.choices.where((item) => item.id == guess.target.id),
      hasLength(1),
    );
    expect(type.choices.toSet(), hasLength(3));
    expect(
      type.choices.where((item) => item == type.correctType),
      hasLength(1),
    );
    expect(
      attackMultiplier(type.correctType, type.opponent.types),
      greaterThan(1),
    );
    expect(
      type.choices
          .where((item) => item != type.correctType)
          .map((item) => attackMultiplier(item, type.opponent.types)),
      everyElement(lessThanOrEqualTo(1)),
    );
    expect(evolution.choices.map((item) => item.id).toSet(), hasLength(3));
    expect(
      evolution.from.evolutionEdges
          .where((edge) => species.any((item) => item.id == edge.toSpeciesId))
          .map((edge) => edge.toSpeciesId)
          .toSet(),
      {evolution.to.id},
    );
  });

  test('personalization prefers partner and collection when valid', () {
    final partner = species.firstWhere((pokemon) => pokemon.id == 25);
    final bulbasaur = species.firstWhere((pokemon) => pokemon.id == 1);
    final adventure = service.buildFreePlay(
      seed: 9,
      species: species,
      collection: {
        bulbasaur.id: CollectionState(speciesId: bulbasaur.id, isCaught: true),
      },
      partner: partner,
    );

    final type = adventure.rounds[1] as TypePowerRound;
    final evolution = adventure.rounds[2] as EvolutionTrailRound;
    expect({partner.id, bulbasaur.id}, contains(type.opponent.id));
    expect(evolution.from.id, bulbasaur.id);
  });

  test('out-of-roster species never appear and Free Play varies by seed', () {
    final sprigatito = _pokemon(906, 'Sprigatito', ['Grass']);
    final focusIds = <int>{};
    for (var seed = 1; seed <= 20; seed++) {
      final adventure = service.buildFreePlay(
        seed: seed,
        species: [...species, sprigatito],
        collection: const {},
        partner: species.first,
      );
      final guess = adventure.rounds.first as PokemonGuessRound;
      focusIds.add(guess.target.id);
      expect(
        adventure.rounds
            .whereType<PokemonGuessRound>()
            .expand((round) => round.choices)
            .map((item) => item.id),
        isNot(contains(906)),
      );
    }
    expect(focusIds.length, greaterThan(1));
  });
}

String _signature(MiniAdventure adventure) {
  final guess = adventure.rounds[0] as PokemonGuessRound;
  final type = adventure.rounds[1] as TypePowerRound;
  final evolution = adventure.rounds[2] as EvolutionTrailRound;
  return [
    adventure.id,
    adventure.reward?.id,
    guess.choices.map((item) => item.id).join(','),
    type.opponent.id,
    type.choices.join(','),
    evolution.from.id,
    evolution.choices.map((item) => item.id).join(','),
  ].join('|');
}

List<PokemonSpecies> _speciesFixture() {
  return [
    _pokemon(1, 'Bulbasaur', ['Grass', 'Poison'], evolvesTo: 2),
    _pokemon(2, 'Ivysaur', ['Grass', 'Poison']),
    _pokemon(4, 'Charmander', ['Fire'], evolvesTo: 5),
    _pokemon(5, 'Charmeleon', ['Fire']),
    _pokemon(7, 'Squirtle', ['Water'], evolvesTo: 8),
    _pokemon(8, 'Wartortle', ['Water']),
    _pokemon(25, 'Pikachu', ['Electric']),
  ];
}

PokemonSpecies _pokemon(
  int id,
  String name,
  List<String> types, {
  int? evolvesTo,
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
    evolutionEdges: [
      if (evolvesTo != null)
        EvolutionEdge(
          fromSpeciesId: id,
          toSpeciesId: evolvesTo,
          condition: 'Level up',
          sortOrder: 0,
        ),
    ],
  );
}
