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
                'Choose a Gym. Plan for each opponent with strong move types and Let’s Go-compatible helpers.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Guide covers the first story battle in Let’s Go Pikachu and Eevee.',
              ),
              const SizedBox(height: 18),
              for (final gym in gyms) ...[
                _GymCard(
                  gym: gym,
                  controller: controller,
                  onOpenPokemon: onOpenPokemon,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({
    required this.gym,
    required this.controller,
    required this.onOpenPokemon,
  });

  final GymGuide gym;
  final AdventureController controller;
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
              ),
              level: opponent.level,
              onOpenPokemon: onOpenPokemon,
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Check that your Pokémon knows a matching move. Level and stats matter too. Helpers may be found later or differ by game version.',
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
    required this.onOpenPokemon,
  });

  final GymOpponentAdvice advice;
  final int level;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  Widget build(BuildContext context) {
    final opponent = advice.opponent;
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
            Text('Use these move types against ${opponent.name}:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final moveType in advice.moveTypes)
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
            ),
            const SizedBox(height: 12),
            Text(
              'Let’s Go helpers with matching moves',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (advice.helpers.isEmpty)
              const Text('No matching helpers are listed in this dataset.')
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
                      for (final helper in advice.helpers)
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
          ],
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
