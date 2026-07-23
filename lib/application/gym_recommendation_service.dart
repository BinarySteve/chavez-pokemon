import '../domain/battle/type_matchups.dart';
import '../domain/lets_go_species.dart';
import '../domain/models/encounter_guide.dart';
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

class GymEncounterLocation {
  const GymEncounterLocation({
    required this.area,
    required this.method,
    required this.minLevel,
    required this.maxLevel,
    required this.versions,
  });

  final LetsGoEncounterArea area;
  final String method;
  final int minLevel;
  final int maxLevel;
  final List<LetsGoVersion> versions;

  bool get isRare => method == 'overworld-special';
  bool get isBothGames =>
      versions.contains(LetsGoVersion.pikachu) &&
      versions.contains(LetsGoVersion.eevee);

  String get methodLabel => isRare ? 'Rare spawn' : 'Wild';

  String get versionLabel {
    if (isBothGames) {
      return 'Both games';
    }
    return versions.single == LetsGoVersion.pikachu
        ? 'Pikachu version'
        : 'Eevee version';
  }
}

class GymCatchSuggestion {
  const GymCatchSuggestion({
    required this.pokemon,
    required this.moveTypes,
    required this.locations,
  });

  final PokemonSpecies pokemon;
  final List<GymMoveTypeAdvice> moveTypes;
  final List<GymEncounterLocation> locations;

  double get bestMultiplier => moveTypes.first.multiplier;
  bool get hasRegularEncounter => locations.any((location) => !location.isRare);
  bool get isAvailableInBothGames =>
      locations.any((location) => location.isBothGames);
}

class GymOpponentAdvice {
  const GymOpponentAdvice({
    required this.opponent,
    required this.moveTypes,
    required this.caughtHelpers,
    required this.catchSuggestions,
  });

  final PokemonSpecies opponent;
  final List<GymMoveTypeAdvice> moveTypes;
  final List<GymHelperRecommendation> caughtHelpers;
  final List<GymCatchSuggestion> catchSuggestions;
}

class GymRecommendationService {
  const GymRecommendationService();

  GymOpponentAdvice recommendForOpponent({
    required PokemonSpecies opponent,
    required Iterable<PokemonSpecies> candidates,
    required Set<int> caughtSpeciesIds,
    required EncounterGuide encounterGuide,
    required int gymBadgeNumber,
    int caughtLimit = 4,
    int suggestionLimit = 3,
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
    final caughtHelpers = <GymHelperRecommendation>[];
    final catchSuggestions = <GymCatchSuggestion>[];

    final eligibleBySpecies = _eligibleEncounters(
      encounterGuide,
      gymBadgeNumber,
    );
    for (final pokemon in candidates) {
      if (!isLetsGoSpecies(pokemon.id)) {
        continue;
      }
      final matchingTypes = _matchingMoveTypes(pokemon, adviceByType);
      if (matchingTypes.isEmpty) {
        continue;
      }
      if (caughtSpeciesIds.contains(pokemon.id)) {
        caughtHelpers.add(
          GymHelperRecommendation(
            pokemon: pokemon,
            moveTypes: List.unmodifiable(matchingTypes),
          ),
        );
        continue;
      }
      final encounters = eligibleBySpecies[pokemon.id];
      if (encounters == null || encounters.isEmpty) {
        continue;
      }
      catchSuggestions.add(
        GymCatchSuggestion(
          pokemon: pokemon,
          moveTypes: List.unmodifiable(matchingTypes),
          locations: List.unmodifiable(
            _combineLocations(encounters, encounterGuide.areas).take(2),
          ),
        ),
      );
    }

    caughtHelpers.sort(_compareHelpers);
    catchSuggestions.sort(_compareSuggestions);
    return GymOpponentAdvice(
      opponent: opponent,
      moveTypes: List.unmodifiable(moveTypes),
      caughtHelpers: List.unmodifiable(
        caughtHelpers.take(caughtLimit < 0 ? 0 : caughtLimit),
      ),
      catchSuggestions: List.unmodifiable(
        catchSuggestions.take(suggestionLimit < 0 ? 0 : suggestionLimit),
      ),
    );
  }

  static Map<int, List<LetsGoEncounter>> _eligibleEncounters(
    EncounterGuide guide,
    int gymBadgeNumber,
  ) {
    final result = <int, List<LetsGoEncounter>>{};
    for (final encounter in guide.encounters) {
      final area = guide.areas[encounter.areaId];
      if (area == null ||
          area.requiredBadges >= gymBadgeNumber ||
          encounter.conditions.isNotEmpty ||
          (encounter.method != 'overworld' &&
              encounter.method != 'overworld-special')) {
        continue;
      }
      result.putIfAbsent(encounter.speciesId, () => []).add(encounter);
    }
    return result;
  }

  static List<GymMoveTypeAdvice> _matchingMoveTypes(
    PokemonSpecies pokemon,
    Map<String, GymMoveTypeAdvice> adviceByType,
  ) {
    return pokemon.moves
        .map((move) => move.type)
        .toSet()
        .map((type) => adviceByType[type])
        .whereType<GymMoveTypeAdvice>()
        .toList()
      ..sort(_compareMoveTypes);
  }

  static List<GymEncounterLocation> _combineLocations(
    List<LetsGoEncounter> encounters,
    Map<int, LetsGoEncounterArea> areas,
  ) {
    final grouped = <(int, String), _LocationAccumulator>{};
    for (final encounter in encounters) {
      final key = (encounter.areaId, encounter.method);
      grouped
          .putIfAbsent(
            key,
            () => _LocationAccumulator(
              minLevel: encounter.minLevel,
              maxLevel: encounter.maxLevel,
            ),
          )
          .include(encounter);
    }
    final locations = [
      for (final entry in grouped.entries)
        GymEncounterLocation(
          area: areas[entry.key.$1]!,
          method: entry.key.$2,
          minLevel: entry.value.minLevel,
          maxLevel: entry.value.maxLevel,
          versions: List.unmodifiable(entry.value.versions),
        ),
    ];
    locations.sort((left, right) {
      final progress = right.area.requiredBadges.compareTo(
        left.area.requiredBadges,
      );
      if (progress != 0) return progress;
      final rarity = left.isRare == right.isRare ? 0 : (left.isRare ? 1 : -1);
      if (rarity != 0) return rarity;
      final versions = left.isBothGames == right.isBothGames
          ? 0
          : (left.isBothGames ? -1 : 1);
      if (versions != 0) return versions;
      return left.area.displayName.compareTo(right.area.displayName);
    });
    return locations;
  }

  static int _compareHelpers(
    GymHelperRecommendation left,
    GymHelperRecommendation right,
  ) {
    final multiplier = right.bestMultiplier.compareTo(left.bestMultiplier);
    if (multiplier != 0) return multiplier;
    final variety = right.moveTypes.length.compareTo(left.moveTypes.length);
    if (variety != 0) return variety;
    return left.pokemon.dexNumber.compareTo(right.pokemon.dexNumber);
  }

  static int _compareSuggestions(
    GymCatchSuggestion left,
    GymCatchSuggestion right,
  ) {
    final multiplier = right.bestMultiplier.compareTo(left.bestMultiplier);
    if (multiplier != 0) return multiplier;
    final regular = left.hasRegularEncounter == right.hasRegularEncounter
        ? 0
        : (left.hasRegularEncounter ? -1 : 1);
    if (regular != 0) return regular;
    final versions = left.isAvailableInBothGames == right.isAvailableInBothGames
        ? 0
        : (left.isAvailableInBothGames ? -1 : 1);
    if (versions != 0) return versions;
    final variety = right.moveTypes.length.compareTo(left.moveTypes.length);
    if (variety != 0) return variety;
    return left.pokemon.dexNumber.compareTo(right.pokemon.dexNumber);
  }

  static int _compareMoveTypes(
    GymMoveTypeAdvice left,
    GymMoveTypeAdvice right,
  ) {
    final multiplier = right.multiplier.compareTo(left.multiplier);
    return multiplier != 0 ? multiplier : left.type.compareTo(right.type);
  }
}

class _LocationAccumulator {
  _LocationAccumulator({required this.minLevel, required this.maxLevel});

  int minLevel;
  int maxLevel;
  final Set<LetsGoVersion> versions = {};

  void include(LetsGoEncounter encounter) {
    if (encounter.minLevel < minLevel) minLevel = encounter.minLevel;
    if (encounter.maxLevel > maxLevel) maxLevel = encounter.maxLevel;
    versions.addAll(encounter.versions);
  }
}
