import '../domain/battle/type_matchups.dart';
import '../domain/lets_go_species.dart';
import '../domain/models/activity_progress.dart';
import '../domain/models/collection_state.dart';
import '../domain/models/mini_adventure.dart';
import '../domain/models/pokemon_species.dart';

class MiniAdventureService {
  const MiniAdventureService();

  static const algorithmVersion = 1;

  MiniAdventure buildDaily({
    required DateTime localDate,
    required Iterable<PokemonSpecies> species,
    required Map<int, CollectionState> collection,
    required PokemonSpecies? partner,
    required ActivityProgress progress,
  }) {
    final roster = _roster(species);
    final date = formatLocalDate(localDate);
    final serialDay =
        DateTime.utc(
          localDate.year,
          localDate.month,
          localDate.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final start = _positiveModulo(serialDay, roster.length);
    final activityId = 'daily-v$algorithmVersion-$date';
    final existingCompletion = progress.completions[activityId];
    PokemonSpecies? reward;
    if (existingCompletion != null) {
      final rewardId = existingCompletion.rewardSpeciesId;
      if (rewardId != null) {
        reward = roster.where((pokemon) => pokemon.id == rewardId).firstOrNull;
      }
    } else {
      for (var offset = 0; offset < roster.length; offset++) {
        final candidate = roster[(start + offset) % roster.length];
        if (!progress.hasSticker(candidate.id)) {
          reward = candidate;
          break;
        }
      }
    }
    final focus = reward ?? roster[start];
    final random = _StableRandom(serialDay ^ 0x4d415031);
    return MiniAdventure(
      id: activityId,
      activityDate: date,
      isDaily: true,
      reward: reward,
      rounds: List.unmodifiable(
        _buildRounds(
          roster: roster,
          focus: focus,
          collection: collection,
          partner: partner,
          random: random,
        ),
      ),
    );
  }

  MiniAdventure buildFreePlay({
    required int seed,
    required Iterable<PokemonSpecies> species,
    required Map<int, CollectionState> collection,
    required PokemonSpecies? partner,
  }) {
    final roster = _roster(species);
    final random = _StableRandom(seed);
    final focus = roster[random.nextInt(roster.length)];
    return MiniAdventure(
      id: 'free-v$algorithmVersion-$seed',
      activityDate: '',
      isDaily: false,
      reward: null,
      rounds: List.unmodifiable(
        _buildRounds(
          roster: roster,
          focus: focus,
          collection: collection,
          partner: partner,
          random: random,
        ),
      ),
    );
  }

  static String formatLocalDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  List<AdventureRound> _buildRounds({
    required List<PokemonSpecies> roster,
    required PokemonSpecies focus,
    required Map<int, CollectionState> collection,
    required PokemonSpecies? partner,
    required _StableRandom random,
  }) {
    final preferred = _preferredPokemon(
      roster: roster,
      collection: collection,
      partner: partner,
    );
    final typeOpponent = _chooseTypeOpponent(
      preferred.isEmpty ? roster : preferred,
      roster,
      random,
    );
    final evolutionSources = _evolutionSources(roster);
    final preferredEvolutionSources = evolutionSources
        .where((pokemon) => preferred.any((item) => item.id == pokemon.id))
        .toList(growable: false);
    final evolutionFrom = _choose(
      preferredEvolutionSources.isEmpty
          ? evolutionSources
          : preferredEvolutionSources,
      random,
    );
    final evolutionTargetId = evolutionFrom.evolutionEdges
        .map((edge) => edge.toSpeciesId)
        .where((id) => roster.any((pokemon) => pokemon.id == id))
        .toSet()
        .single;
    final evolutionTo = roster.singleWhere(
      (pokemon) => pokemon.id == evolutionTargetId,
    );

    return [
      PokemonGuessRound(
        target: focus,
        choices: List.unmodifiable(_speciesChoices(focus, roster, random)),
      ),
      _typeRound(typeOpponent, random),
      EvolutionTrailRound(
        from: evolutionFrom,
        to: evolutionTo,
        choices: List.unmodifiable(
          _speciesChoices(evolutionTo, roster, random),
        ),
      ),
    ];
  }

  TypePowerRound _typeRound(PokemonSpecies opponent, _StableRandom random) {
    final matchups = defensiveMatchups(opponent.types);
    final effective =
        matchups.entries.where((entry) => entry.value > 1).toList()
          ..sort((left, right) {
            final multiplier = right.value.compareTo(left.value);
            return multiplier != 0 ? multiplier : left.key.compareTo(right.key);
          });
    final ineffective =
        matchups.entries.where((entry) => entry.value <= 1).toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    final correct = effective[random.nextInt(effective.length)];
    final wrong = _takeDistinct(ineffective, 2, random);
    final choices = [correct.key, ...wrong.map((entry) => entry.key)];
    random.shuffle(choices);
    return TypePowerRound(
      opponent: opponent,
      choices: List.unmodifiable(choices),
      correctType: correct.key,
      multiplier: correct.value,
    );
  }

  static List<PokemonSpecies> _roster(Iterable<PokemonSpecies> species) {
    final roster =
        species.where((pokemon) => isLetsGoSpecies(pokemon.id)).toList()
          ..sort((left, right) => left.dexNumber.compareTo(right.dexNumber));
    if (roster.length < 3 || _evolutionSources(roster).isEmpty) {
      throw StateError('Mini adventures need a complete Let’s Go roster.');
    }
    return roster;
  }

  static List<PokemonSpecies> _preferredPokemon({
    required List<PokemonSpecies> roster,
    required Map<int, CollectionState> collection,
    required PokemonSpecies? partner,
  }) {
    final preferredIds = <int>{
      if (partner != null && isLetsGoSpecies(partner.id)) partner.id,
      for (final entry in collection.entries)
        if (entry.value.isCaught || entry.value.isFavorite) entry.key,
    };
    return roster
        .where(
          (pokemon) =>
              preferredIds.contains(pokemon.id) &&
              defensiveMatchups(
                pokemon.types,
              ).values.any((multiplier) => multiplier > 1),
        )
        .toList(growable: false);
  }

  static PokemonSpecies _chooseTypeOpponent(
    List<PokemonSpecies> candidates,
    List<PokemonSpecies> roster,
    _StableRandom random,
  ) {
    final eligible = candidates
        .where(
          (pokemon) => defensiveMatchups(
            pokemon.types,
          ).values.any((multiplier) => multiplier > 1),
        )
        .toList(growable: false);
    if (eligible.isNotEmpty) return _choose(eligible, random);
    return _choose(
      roster
          .where(
            (pokemon) => defensiveMatchups(
              pokemon.types,
            ).values.any((multiplier) => multiplier > 1),
          )
          .toList(growable: false),
      random,
    );
  }

  static List<PokemonSpecies> _evolutionSources(List<PokemonSpecies> roster) {
    final rosterIds = roster.map((pokemon) => pokemon.id).toSet();
    return roster
        .where((pokemon) {
          final targets = pokemon.evolutionEdges
              .map((edge) => edge.toSpeciesId)
              .where(rosterIds.contains)
              .toSet();
          return targets.length == 1;
        })
        .toList(growable: false);
  }

  static List<PokemonSpecies> _speciesChoices(
    PokemonSpecies correct,
    List<PokemonSpecies> roster,
    _StableRandom random,
  ) {
    final others = roster
        .where((pokemon) => pokemon.id != correct.id)
        .toList(growable: false);
    final choices = [correct, ..._takeDistinct(others, 2, random)];
    random.shuffle(choices);
    return choices;
  }

  static T _choose<T>(List<T> values, _StableRandom random) {
    if (values.isEmpty) throw StateError('No eligible activity choices.');
    return values[random.nextInt(values.length)];
  }

  static List<T> _takeDistinct<T>(
    List<T> values,
    int count,
    _StableRandom random,
  ) {
    if (values.length < count) {
      throw StateError('Not enough distinct activity choices.');
    }
    final available = List<T>.of(values);
    final result = <T>[];
    while (result.length < count) {
      result.add(available.removeAt(random.nextInt(available.length)));
    }
    return result;
  }

  static int _positiveModulo(int value, int modulus) {
    final result = value % modulus;
    return result < 0 ? result + modulus : result;
  }
}

class _StableRandom {
  _StableRandom(int seed) : _state = seed & 0xffffffff;

  int _state;

  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max');
    _state = (1664525 * _state + 1013904223) & 0xffffffff;
    return _state % max;
  }

  void shuffle<T>(List<T> values) {
    for (var index = values.length - 1; index > 0; index--) {
      final other = nextInt(index + 1);
      final value = values[index];
      values[index] = values[other];
      values[other] = value;
    }
  }
}
