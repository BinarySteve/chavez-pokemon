import 'package:flutter/foundation.dart';

import 'pokemon_species.dart';

@immutable
class MiniAdventure {
  const MiniAdventure({
    required this.id,
    required this.activityDate,
    required this.isDaily,
    required this.reward,
    required this.rounds,
  });

  final String id;
  final String activityDate;
  final bool isDaily;
  final PokemonSpecies? reward;
  final List<AdventureRound> rounds;
}

@immutable
sealed class AdventureRound {
  const AdventureRound();

  String get title;
}

@immutable
class PokemonGuessRound extends AdventureRound {
  const PokemonGuessRound({required this.target, required this.choices});

  final PokemonSpecies target;
  final List<PokemonSpecies> choices;

  @override
  String get title => 'Who’s That Pokémon?';
}

@immutable
class TypePowerRound extends AdventureRound {
  const TypePowerRound({
    required this.opponent,
    required this.choices,
    required this.correctType,
    required this.multiplier,
  });

  final PokemonSpecies opponent;
  final List<String> choices;
  final String correctType;
  final double multiplier;

  @override
  String get title => 'Type Power!';
}

@immutable
class EvolutionTrailRound extends AdventureRound {
  const EvolutionTrailRound({
    required this.from,
    required this.to,
    required this.choices,
  });

  final PokemonSpecies from;
  final PokemonSpecies to;
  final List<PokemonSpecies> choices;

  @override
  String get title => 'Evolution Trail';
}
