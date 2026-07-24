import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../application/gym_recommendation_service.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';
import 'widgets/type_badge.dart';

class GymGuideScreen extends StatelessWidget {
  const GymGuideScreen({
    required this.controller,
    required this.onOpenPokemon,
    super.key,
  });

  final AdventureController controller;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final caughtSpeciesIds = {
          for (final pokemon in controller.species)
            if (controller.collectionFor(pokemon.id).isCaught) pokemon.id,
        };
        return CustomScrollView(
          key: const PageStorageKey('gym-guide-scroll'),
          slivers: [
            SliverAppBar.large(
              title: const Text('Let’s Go Gyms'),
              automaticallyImplyLeading: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.list(
                children: [
                  Text(
                    'Choose a Gym. We’ll start with your caught Pokémon, then show a few helpers you can find along the way.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mark a Pokémon as Caught to include it in your helper choices.',
                  ),
                  const SizedBox(height: 18),
                  for (final gym in gyms) ...[
                    _GymCard(
                      gym: gym,
                      controller: controller,
                      caughtSpeciesIds: caughtSpeciesIds,
                      onOpenPokemon: onOpenPokemon,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({
    required this.gym,
    required this.controller,
    required this.caughtSpeciesIds,
    required this.onOpenPokemon,
  });

  final GymGuide gym;
  final AdventureController controller;
  final Set<int> caughtSpeciesIds;
  final ValueChanged<PokemonSpecies> onOpenPokemon;
  static const _recommendations = GymRecommendationService();

  @override
  Widget build(BuildContext context) {
    final opponents = [
      for (final member in gym.team)
        if (controller.speciesById(member.speciesId) case final pokemon?)
          _ResolvedOpponent(pokemon: pokemon, level: member.level),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('gym-${gym.badgeNumber}'),
        leading: CircleAvatar(child: Text('${gym.badgeNumber}')),
        title: Text('${gym.leader} · ${gym.city}'),
        subtitle: Text('${gym.specialty}-type Gym · ${gym.badge}'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text('Their team', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final opponent in opponents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PokemonEmblem(pokemon: opponent.pokemon, size: 52),
              title: Text(opponent.pokemon.name),
              subtitle: Text('Level ${opponent.level}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  for (final type in opponent.pokemon.types)
                    TypeBadge(type: type, compact: true),
                ],
              ),
              onTap: () => onOpenPokemon(opponent.pokemon),
            ),
          const SizedBox(height: 12),
          Text(
            'Plan for each Pokémon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          for (final opponent in opponents) ...[
            _OpponentAdviceCard(
              advice: _recommendations.recommendForOpponent(
                opponent: opponent.pokemon,
                candidates: controller.species,
                caughtSpeciesIds: caughtSpeciesIds,
                encounterGuide: controller.encounterGuide,
                gymBadgeNumber: gym.badgeNumber,
              ),
              level: opponent.level,
              gymLeader: gym.leader,
              onOpenPokemon: onOpenPokemon,
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Check that your helper knows the move. Level and stats matter too.',
          ),
        ],
      ),
    );
  }
}

class _ResolvedOpponent {
  const _ResolvedOpponent({required this.pokemon, required this.level});

  final PokemonSpecies pokemon;
  final int level;
}

class _OpponentAdviceCard extends StatelessWidget {
  const _OpponentAdviceCard({
    required this.advice,
    required this.level,
    required this.gymLeader,
    required this.onOpenPokemon,
  });

  final GymOpponentAdvice advice;
  final int level;
  final String gymLeader;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  Widget build(BuildContext context) {
    final opponent = advice.opponent;
    final bestMultiplier = advice.moveTypes.isEmpty
        ? 0.0
        : advice.moveTypes.first.multiplier;
    final bestMoveTypes = advice.moveTypes
        .where((moveType) => moveType.multiplier == bestMultiplier)
        .toList(growable: false);
    final otherMoveTypes = advice.moveTypes
        .where((moveType) => moveType.multiplier != bestMultiplier)
        .toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Against ${opponent.name} · Level $level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Best move types against ${opponent.name}:'),
            const SizedBox(height: 8),
            _MoveTypeChoices(moveTypes: bestMoveTypes, opponent: opponent),
            if (otherMoveTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'These can help too:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              _MoveTypeChoices(moveTypes: otherMoveTypes, opponent: opponent),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 20),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Your caught helpers',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (advice.caughtHelpers.isEmpty)
              _NoCaughtHelper(
                bestMoveTypes: bestMoveTypes,
                hasCatchSuggestions: advice.catchSuggestions.isNotEmpty,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                  final width = largeText
                      ? constraints.maxWidth
                      : constraints.maxWidth < 220
                      ? constraints.maxWidth
                      : 220.0;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final helper in advice.caughtHelpers)
                        SizedBox(
                          width: width,
                          child: _HelperTile(
                            helper: helper,
                            opponent: opponent,
                            onTap: () => onOpenPokemon(helper.pokemon),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (advice.catchSuggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.explore_rounded, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'You can catch these before $gymLeader',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final suggestion in advice.catchSuggestions) ...[
                _CatchSuggestionTile(
                  suggestion: suggestion,
                  opponent: opponent,
                  onTap: () => onOpenPokemon(suggestion.pokemon),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CatchSuggestionTile extends StatelessWidget {
  const _CatchSuggestionTile({
    required this.suggestion,
    required this.opponent,
    required this.onTap,
  });

  final GymCatchSuggestion suggestion;
  final PokemonSpecies opponent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moveSummary = suggestion.moveTypes
        .take(2)
        .map((item) => '${item.type} ${_multiplierLabel(item.multiplier)}')
        .join(' · ');
    final locationSummary = suggestion.locations.map(_locationLabel).join('. ');
    return Semantics(
      button: true,
      label:
          'Open ${suggestion.pokemon.name}. Against ${opponent.name}: '
          '$moveSummary. $locationSummary',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PokemonEmblem(pokemon: suggestion.pokemon, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.pokemon.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'Helpful move types: $moveSummary',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 5),
                      for (final location in suggestion.locations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _locationLabel(location),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelperTile extends StatelessWidget {
  const _HelperTile({
    required this.helper,
    required this.opponent,
    required this.onTap,
  });

  final GymHelperRecommendation helper;
  final PokemonSpecies opponent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moveSummary = helper.moveTypes
        .take(2)
        .map((item) => '${item.type} ${_multiplierLabel(item.multiplier)}')
        .join(' · ');
    return Semantics(
      button: true,
      label:
          'Open ${helper.pokemon.name}. Against ${opponent.name}: $moveSummary',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                PokemonEmblem(pokemon: helper.pokemon, size: 44),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helper.pokemon.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'Against ${opponent.name}: $moveSummary',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveTypeChoices extends StatelessWidget {
  const _MoveTypeChoices({required this.moveTypes, required this.opponent});

  final List<GymMoveTypeAdvice> moveTypes;
  final PokemonSpecies opponent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final moveType in moveTypes)
          Semantics(
            label:
                '${moveType.type} moves do ${_multiplierWords(moveType.multiplier)} damage against ${opponent.name}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeBadge(type: moveType.type, compact: true),
                const SizedBox(width: 5),
                Text(_multiplierLabel(moveType.multiplier)),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoCaughtHelper extends StatelessWidget {
  const _NoCaughtHelper({
    required this.bestMoveTypes,
    required this.hasCatchSuggestions,
  });

  final List<GymMoveTypeAdvice> bestMoveTypes;
  final bool hasCatchSuggestions;

  @override
  Widget build(BuildContext context) {
    final types = _joinTypeNames(bestMoveTypes.map((item) => item.type));
    final suggestion = types.isEmpty
        ? 'Look through your team for a Pokémon with a strong move.'
        : 'Look through your team for a Pokémon that knows a $types move.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No matching caught helper yet.',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              hasCatchSuggestions
                  ? 'That’s okay! Here are a few you can find before this Gym.'
                  : 'That’s okay! $suggestion Mark it Caught in your Collection when you have it.',
            ),
          ],
        ),
      ),
    );
  }
}

String _locationLabel(GymEncounterLocation location) {
  final level = location.minLevel == location.maxLevel
      ? 'Lv. ${location.minLevel}'
      : 'Lv. ${location.minLevel}–${location.maxLevel}';
  return '${location.area.displayName} · ${location.methodLabel} · '
      '$level · ${location.versionLabel}';
}

String _joinTypeNames(Iterable<String> types) {
  final values = types.toList(growable: false);
  return switch (values.length) {
    0 => '',
    1 => values.single,
    2 => '${values.first} or ${values.last}',
    _ => '${values.take(values.length - 1).join(', ')}, or ${values.last}',
  };
}

String _multiplierLabel(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}×' : '$value×';

String _multiplierWords(double value) =>
    value == value.roundToDouble() ? '${value.toInt()} times' : '$value times';

class GymGuide {
  const GymGuide(
    this.badgeNumber,
    this.leader,
    this.city,
    this.specialty,
    this.badge,
    this.team,
  );
  final int badgeNumber;
  final String leader;
  final String city;
  final String specialty;
  final String badge;
  final List<GymMember> team;
}

class GymMember {
  const GymMember(this.speciesId, this.level);
  final int speciesId;
  final int level;
}

const gyms = <GymGuide>[
  GymGuide(1, 'Brock', 'Pewter City', 'Rock', 'Boulder Badge', [
    GymMember(74, 11),
    GymMember(95, 12),
  ]),
  GymGuide(2, 'Misty', 'Cerulean City', 'Water', 'Cascade Badge', [
    GymMember(54, 18),
    GymMember(121, 19),
  ]),
  GymGuide(3, 'Lt. Surge', 'Vermilion City', 'Electric', 'Thunder Badge', [
    GymMember(100, 25),
    GymMember(81, 25),
    GymMember(26, 26),
  ]),
  GymGuide(4, 'Erika', 'Celadon City', 'Grass', 'Rainbow Badge', [
    GymMember(114, 33),
    GymMember(70, 33),
    GymMember(45, 34),
  ]),
  GymGuide(5, 'Koga', 'Fuchsia City', 'Poison', 'Soul Badge', [
    GymMember(110, 43),
    GymMember(89, 43),
    GymMember(42, 43),
    GymMember(49, 44),
  ]),
  GymGuide(6, 'Sabrina', 'Saffron City', 'Psychic', 'Marsh Badge', [
    GymMember(122, 43),
    GymMember(80, 43),
    GymMember(124, 43),
    GymMember(65, 44),
  ]),
  GymGuide(7, 'Blaine', 'Cinnabar Island', 'Fire', 'Volcano Badge', [
    GymMember(126, 47),
    GymMember(78, 47),
    GymMember(38, 47),
    GymMember(59, 48),
  ]),
  GymGuide(8, 'Giovanni', 'Viridian City', 'Ground', 'Earth Badge', [
    GymMember(51, 49),
    GymMember(31, 49),
    GymMember(34, 49),
    GymMember(112, 50),
  ]),
];
