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
    required this.onOpenAdventureCamp,
    super.key,
  });

  final AdventureController controller;
  final ValueChanged<PokemonSpecies> onOpenPokemon;
  final VoidCallback onOpenAdventureCamp;

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
                          onChangePartner: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            showDragHandle: true,
                            builder: (context) =>
                                _PartnerPickerSheet(controller: controller),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AdventureCampCard(
                          controller: controller,
                          onTap: onOpenAdventureCamp,
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

class _AdventureCampCard extends StatelessWidget {
  const _AdventureCampCard({required this.controller, required this.onTap});

  final AdventureController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = controller.isTodayAdventureComplete;
    final stickerCount = controller.activityProgress.earnedStickers.length;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
                child: Icon(
                  complete ? Icons.check_rounded : Icons.auto_awesome_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s mini adventure',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      complete
                          ? 'Adventure complete! You can play it again anytime.'
                          : 'Three playful rounds and a new sticker are waiting.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$stickerCount of 153 stickers found',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
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
    required this.onChangePartner,
  });

  final String trainerName;
  final PokemonSpecies partner;
  final VoidCallback onTap;
  final VoidCallback onChangePartner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Your partner is ${partner.name}',
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
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onChangePartner,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Change partner'),
                      ),
                      TextButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('View details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerPickerSheet extends StatefulWidget {
  const _PartnerPickerSheet({required this.controller});

  final AdventureController controller;

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _savingSpeciesId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = widget.controller.partner!.id;
    final results = widget.controller.species
        .where((pokemon) => pokemon.matches(_query))
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a new partner',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Pick any Pokémon. Trainer progress will stay the same.',
                ),
                const SizedBox(height: 14),
                SearchBar(
                  controller: _searchController,
                  hintText: 'Search by name, form, or number',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 10),
                Text(
                  '${results.length} Pokémon',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No Pokémon found.'))
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final pokemon = results[index];
                      final isCurrent = pokemon.id == currentId;
                      final isSaving = _savingSpeciesId == pokemon.id;
                      return ListTile(
                        enabled: _savingSpeciesId == null && !isCurrent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        leading: PokemonEmblem(pokemon: pokemon, size: 58),
                        title: Text(pokemon.name),
                        subtitle: Text(
                          '${pokemon.dexLabel} · ${pokemon.types.join(' / ')}',
                        ),
                        trailing: isCurrent
                            ? const Chip(label: Text('Current partner'))
                            : isSaving
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: isCurrent ? null : () => _choose(pokemon),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(PokemonSpecies pokemon) async {
    setState(() => _savingSpeciesId = pokemon.id);
    try {
      await widget.controller.changePartner(pokemon.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } on Object {
      if (!mounted) return;
      setState(() => _savingSpeciesId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner could not be changed. Please try again.'),
        ),
      );
    }
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
              excludeSemantics: true,
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

class _UpdateStatusCard extends StatefulWidget {
  const _UpdateStatusCard({required this.controller});

  final AdventureController controller;

  @override
  State<_UpdateStatusCard> createState() => _UpdateStatusCardState();
}

class _UpdateStatusCardState extends State<_UpdateStatusCard> {
  int? _promptedVersionCode;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final result = controller.updateResult;
    final release = result.release;
    final checking = result.state == UpdateCheckState.checking;
    final updateAvailable =
        result.state == UpdateCheckState.updateAvailable && release != null;
    if (updateAvailable && _promptedVersionCode != release.versionCode) {
      _promptedVersionCode = release.versionCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUpdateDialog(release);
        }
      });
    }

    if (updateAvailable) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A new adventure is ready!',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${release.title} · Version ${release.versionName}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.appUpdateActionState ==
                  AppUpdateActionState.downloading) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: controller.appUpdateDownloadProgress,
                  semanticsLabel: 'Downloading app update',
                  semanticsValue:
                      '${(controller.appUpdateDownloadProgress * 100).round()} percent',
                ),
                const SizedBox(height: 8),
                Text(
                  'Packing the new adventure… '
                  '${(controller.appUpdateDownloadProgress * 100).round()}%',
                ),
              ] else ...[
                if (controller.appUpdateActionMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(message),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _updateButtonAction(controller),
                    icon: Icon(
                      controller.appUpdateActionState ==
                              AppUpdateActionState.waitingForPermission
                          ? Icons.verified_user_outlined
                          : Icons.system_update_rounded,
                    ),
                    label: Text(_updateButtonLabel(controller)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
              result.message,
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

  VoidCallback _updateButtonAction(AdventureController controller) {
    switch (controller.appUpdateActionState) {
      case AppUpdateActionState.waitingForPermission:
      case AppUpdateActionState.openingInstaller:
        return controller.continueAppUpdate;
      case AppUpdateActionState.failed:
        return controller.beginAppUpdate;
      case AppUpdateActionState.idle:
        return () => _showUpdateDialog(controller.updateResult.release!);
      case AppUpdateActionState.downloading:
        return () {};
    }
  }

  String _updateButtonLabel(AdventureController controller) {
    switch (controller.appUpdateActionState) {
      case AppUpdateActionState.waitingForPermission:
        return 'I allowed it—continue';
      case AppUpdateActionState.openingInstaller:
        return 'Open Android update';
      case AppUpdateActionState.failed:
        return 'Try download again';
      case AppUpdateActionState.idle:
        return 'See what’s new';
      case AppUpdateActionState.downloading:
        return 'Downloading…';
    }
  }

  Future<void> _showUpdateDialog(AppUpdateRelease release) async {
    if (!mounted) return;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded, size: 42),
        title: Text(release.title, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A new version is ready to join the team!',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (release.notes.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final note in release.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⭐  '),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Text(
                'Ask a grown-up to help. Android will always ask before installing.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text('Update with a grown-up'),
          ),
        ],
      ),
    );
    if (shouldUpdate == true) {
      await widget.controller.beginAppUpdate();
    }
  }
}
