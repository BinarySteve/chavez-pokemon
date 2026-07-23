import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import '../domain/repositories.dart';
import 'widgets/pokemon_emblem.dart';
import 'widgets/type_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
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
        final partner = controller.partner!;
        final dayIndex =
            DateTime.now().difference(DateTime(2026)).inDays.abs() %
            controller.species.length;
        final pokemonOfDay = controller.species[dayIndex];
        return CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(controller: controller),
                        const SizedBox(height: 24),
                        _PartnerHero(
                          trainerName: controller.profile!.name,
                          partner: partner,
                          onTap: () => onOpenPokemon(partner),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 760) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _ProgressCard(
                                      controller: controller,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: _PokemonOfDayCard(
                                      pokemon: pokemonOfDay,
                                      onTap: () => onOpenPokemon(pokemonOfDay),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _ProgressCard(controller: controller),
                                const SizedBox(height: 18),
                                _PokemonOfDayCard(
                                  pokemon: pokemonOfDay,
                                  onTap: () => onOpenPokemon(pokemonOfDay),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _SuggestionCard(
                          pokemon: _suggestion(controller, partner.id),
                          onTap: onOpenPokemon,
                        ),
                        const SizedBox(height: 16),
                        _UpdateStatusCard(controller: controller),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  PokemonSpecies _suggestion(AdventureController controller, int partnerId) {
    return controller.species.firstWhere(
      (pokemon) =>
          pokemon.id != partnerId &&
          !controller.collectionFor(pokemon.id).isSeen,
      orElse: () => controller.species.first,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${controller.profile!.name}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Ready for a little discovery?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Local trainer profile',
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.explore_rounded),
          ),
        ),
      ],
    );
  }
}

class _PartnerHero extends StatelessWidget {
  const _PartnerHero({
    required this.trainerName,
    required this.partner,
    required this.onTap,
  });

  final String trainerName;
  final PokemonSpecies partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Open partner ${partner.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primaryContainer, scheme.tertiaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              PokemonEmblem(
                pokemon: partner,
                size: 112,
                heroTag: 'pokemon-${partner.id}',
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your partner',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partner.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$trainerName, let’s find something new together.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final type in partner.types) TypeBadge(type: type),
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
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    final total = controller.species.length;
    final progress = total == 0 ? 0.0 : controller.seenCount / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your discovery trail',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              label: '${controller.seenCount} of $total Pokémon seen',
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${controller.seenCount} seen · ${controller.caughtCount} caught · ${controller.favoriteCount} favorites',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _PokemonOfDayCard extends StatelessWidget {
  const _PokemonOfDayCard({required this.pokemon, required this.onTap});

  final PokemonSpecies pokemon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              PokemonEmblem(pokemon: pokemon, size: 74),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pokémon of the day',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pokemon.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(pokemon.classification),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.pokemon, required this.onTap});

  final PokemonSpecies pokemon;
  final ValueChanged<PokemonSpecies> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: const Icon(Icons.lightbulb_outline_rounded),
        title: const Text('Suggested discovery'),
        subtitle: Text('Take a closer look at ${pokemon.name}.'),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: () => onTap(pokemon),
      ),
    );
  }
}

class _UpdateStatusCard extends StatelessWidget {
  const _UpdateStatusCard({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    final checking = controller.updateResult.state == UpdateCheckState.checking;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            checking ? Icons.sync_rounded : Icons.offline_bolt_outlined,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.updateResult.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: checking ? null : controller.checkForUpdates,
            child: const Text('Check again'),
          ),
        ],
      ),
    );
  }
}
