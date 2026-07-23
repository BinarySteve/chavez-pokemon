import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
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
        final entries = controller.species
            .where(
              (pokemon) => controller.collectionFor(pokemon.id).hasAnyProgress,
            )
            .toList(growable: false);
        return CustomScrollView(
          key: const PageStorageKey('collection-scroll'),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('My collection'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: _CollectionSummary(controller: controller),
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_add_outlined, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Your collection is ready.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Open a Pokédex entry to mark what you have seen, caught, or want to find.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 850
                        ? 3
                        : constraints.crossAxisExtent >= 560
                        ? 2
                        : 1;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 2.6 : 2.1,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final pokemon = entries[index];
                        final state = controller.collectionFor(pokemon.id);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpenPokemon(pokemon),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  PokemonEmblem(pokemon: pokemon, size: 66),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pokemon.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            if (state.isFavorite)
                                              const _StateIcon(
                                                icon: Icons.favorite_rounded,
                                                label: 'Favorite',
                                              ),
                                            if (state.isSeen)
                                              const _StateIcon(
                                                icon: Icons.visibility_rounded,
                                                label: 'Seen',
                                              ),
                                            if (state.isCaught)
                                              const _StateIcon(
                                                icon:
                                                    Icons.check_circle_rounded,
                                                label: 'Caught',
                                              ),
                                            if (state.isShiny)
                                              const _StateIcon(
                                                icon:
                                                    Icons.auto_awesome_rounded,
                                                label: 'Shiny',
                                              ),
                                            if (state.wantsToFind)
                                              const _StateIcon(
                                                icon: Icons.flag_rounded,
                                                label: 'Want to find',
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Count(label: 'Seen', value: controller.seenCount),
            _Count(label: 'Caught', value: controller.caughtCount),
            _Count(label: 'Favorites', value: controller.favoriteCount),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
        semanticLabel: label,
      ),
    );
  }
}
