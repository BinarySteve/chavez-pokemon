import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/mini_adventure.dart';
import '../domain/models/pokemon_species.dart';
import 'mini_adventure_screen.dart';
import 'sticker_scrapbook_screen.dart';

class AdventureCampScreen extends StatelessWidget {
  const AdventureCampScreen({
    required this.controller,
    required this.onOpenPokemon,
    super.key,
  });

  final AdventureController controller;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  void _openAdventure(
    BuildContext context,
    MiniAdventure adventure, {
    required bool wasCompleted,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniAdventureScreen(
          controller: controller,
          adventure: adventure,
          wasCompleted: wasCompleted,
          onOpenPokemon: onOpenPokemon,
          onOpenScrapbook: () => _openScrapbook(context),
        ),
      ),
    );
  }

  void _openScrapbook(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StickerScrapbookScreen(
          controller: controller,
          onOpenPokemon: onOpenPokemon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adventure Camp')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'A little play, a little discovery, and no rush.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      if (!controller.isActivityReady)
                        _ActivityLoadingCard(controller: controller)
                      else
                        _TodayCard(
                          controller: controller,
                          onPlay: () {
                            final adventure = controller.buildDailyAdventure();
                            _openAdventure(
                              context,
                              adventure,
                              wasCompleted: controller.activityProgress
                                  .hasCompleted(adventure.id),
                            );
                          },
                        ),
                      const SizedBox(height: 14),
                      _FreePlayCard(
                        onPlay: () => _openAdventure(
                          context,
                          controller.buildFreePlayAdventure(),
                          wasCompleted: false,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ScrapbookCard(
                        controller: controller,
                        onOpen: controller.isActivityReady
                            ? () => _openScrapbook(context)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScrapbookCard extends StatelessWidget {
  const _ScrapbookCard({required this.controller, required this.onOpen});

  final AdventureController controller;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final found = controller.activityProgress.earnedStickers.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 34),
            const SizedBox(height: 12),
            Text(
              'Sticker Scrapbook',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              controller.isActivityReady
                  ? '$found of 153 stickers found. Every page grows one adventure at a time.'
                  : 'Sticker progress will appear when today’s activities are ready.',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.collections_bookmark_rounded),
              label: const Text('Open scrapbook'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLoadingCard extends StatelessWidget {
  const _ActivityLoadingCard({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.activityError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error == null
                  ? 'Opening today’s adventure…'
                  : 'Today’s sticker book needs a quick retry.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (error == null) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Your Pokédex and Collection are still safe. Free Play is ready.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.loadActivityProgress,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.controller, required this.onPlay});

  final AdventureController controller;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final adventure = controller.buildDailyAdventure();
    final complete = controller.activityProgress.hasCompleted(adventure.id);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 36),
            const SizedBox(height: 12),
            Text(
              'Today’s Adventure',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              complete
                  ? 'You found today’s sticker. Replay for fun whenever you like!'
                  : adventure.reward == null
                  ? 'Your scrapbook is complete. Let’s keep exploring!'
                  : 'Finish three friendly rounds to discover a new sticker.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(
                complete ? Icons.replay_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(complete ? 'Play again' : 'Start adventure'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreePlayCard extends StatelessWidget {
  const _FreePlayCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.catching_pokemon_rounded, size: 34),
            const SizedBox(height: 12),
            Text('Free Play', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Play as many practice adventures as you like. No score and no pressure.',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onPlay,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Start Free Play'),
            ),
          ],
        ),
      ),
    );
  }
}
