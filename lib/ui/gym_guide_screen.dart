import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/battle/type_matchups.dart';
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
          title: const Text('Gym battle guide'),
          automaticallyImplyLeading: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(
            children: [
              Text(
                'Choose a Gym. See its team, strong move types, and Pokémon that may help.',
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

  @override
  Widget build(BuildContext context) {
    final opponents = gym.team
        .map((member) => controller.speciesById(member.speciesId))
        .whereType<PokemonSpecies>()
        .toList();
    final usefulTypes = <String>{
      for (final pokemon in opponents) ...bestAttackTypes(pokemon.types),
    };
    final helpers = controller.species
        .where((pokemon) {
          return pokemon.moves.any((move) => usefulTypes.contains(move.type));
        })
        .take(8)
        .toList();

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
          for (var index = 0; index < opponents.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PokemonEmblem(pokemon: opponents[index], size: 52),
              title: Text(opponents[index].name),
              subtitle: Text('Level ${gym.team[index].level}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  for (final type in opponents[index].types)
                    TypeBadge(type: type, compact: true),
                ],
              ),
              onTap: () => onOpenPokemon(opponents[index]),
            ),
          const SizedBox(height: 12),
          Text(
            'Try these move types',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final type in usefulTypes) TypeBadge(type: type)],
          ),
          const SizedBox(height: 14),
          Text(
            'Pokémon that can learn helpful moves',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: ListView.separated(
              key: PageStorageKey('gym-${gym.badgeNumber}-helpers'),
              scrollDirection: Axis.horizontal,
              itemCount: helpers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final pokemon = helpers[index];
                return Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onOpenPokemon(pokemon),
                    child: SizedBox(
                      width: 150,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            PokemonEmblem(pokemon: pokemon, size: 48),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pokemon.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Text(
            'Check that your Pokémon knows a matching move. Level and stats matter too.',
          ),
        ],
      ),
    );
  }
}

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
