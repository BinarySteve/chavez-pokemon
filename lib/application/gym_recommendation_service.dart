import '../domain/battle/type_matchups.dart';
import '../domain/lets_go_species.dart';
import '../domain/models/pokemon_species.dart';

class GymMoveTypeAdvice {
  const GymMoveTypeAdvice({required this.type, required this.multiplier});

  final String type;
  final double multiplier;
}

class GymHelperRecommendation {
  const GymHelperRecommendation({
    required this.pokemon,
    required this.moveTypes,
  });

  final PokemonSpecies pokemon;
  final List<GymMoveTypeAdvice> moveTypes;

  double get bestMultiplier => moveTypes.first.multiplier;
}

class GymOpponentAdvice {
  const GymOpponentAdvice({
    required this.opponent,
    required this.moveTypes,
    required this.helpers,
  });

  final PokemonSpecies opponent;
  final List<GymMoveTypeAdvice> moveTypes;
  final List<GymHelperRecommendation> helpers;
}

class GymRecommendationService {
  const GymRecommendationService();

  GymOpponentAdvice recommendForOpponent({
    required PokemonSpecies opponent,
    required Iterable<PokemonSpecies> candidates,
    int limit = 8,
  }) {
    final moveTypes =
        defensiveMatchups(opponent.types).entries
            .where((entry) => entry.value > 1)
            .map(
              (entry) =>
                  GymMoveTypeAdvice(type: entry.key, multiplier: entry.value),
            )
            .toList()
          ..sort(_compareMoveTypes);
    final adviceByType = {for (final advice in moveTypes) advice.type: advice};
    final helpers = <GymHelperRecommendation>[];

    for (final pokemon in candidates) {
      if (!isLetsGoSpecies(pokemon.id)) {
        continue;
      }
      final matchingTypes =
          pokemon.moves
              .map((move) => move.type)
              .toSet()
              .map((type) => adviceByType[type])
              .whereType<GymMoveTypeAdvice>()
              .toList()
            ..sort(_compareMoveTypes);
      if (matchingTypes.isEmpty) {
        continue;
      }
      helpers.add(
        GymHelperRecommendation(
          pokemon: pokemon,
          moveTypes: List.unmodifiable(matchingTypes),
        ),
      );
    }

    helpers.sort((left, right) {
      final multiplier = right.bestMultiplier.compareTo(left.bestMultiplier);
      if (multiplier != 0) {
        return multiplier;
      }
      final variety = right.moveTypes.length.compareTo(left.moveTypes.length);
      if (variety != 0) {
        return variety;
      }
      return left.pokemon.dexNumber.compareTo(right.pokemon.dexNumber);
    });

    return GymOpponentAdvice(
      opponent: opponent,
      moveTypes: List.unmodifiable(moveTypes),
      helpers: List.unmodifiable(helpers.take(limit < 0 ? 0 : limit)),
    );
  }

  static int _compareMoveTypes(
    GymMoveTypeAdvice left,
    GymMoveTypeAdvice right,
  ) {
    final multiplier = right.multiplier.compareTo(left.multiplier);
    return multiplier != 0 ? multiplier : left.type.compareTo(right.type);
  }
}
