import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';

class StickerScrapbookScreen extends StatelessWidget {
  const StickerScrapbookScreen({
    required this.controller,
    required this.onOpenPokemon,
    super.key,
  });

  static final stickerSpeciesIds = List<int>.unmodifiable([
    for (var id = 1; id <= 151; id++) id,
    808,
    809,
  ]);

  final AdventureController controller;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sticker Scrapbook')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final earned = controller.activityProgress.earnedStickers;
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.min(constraints.maxWidth - 40, 1080.0);
              final largeText =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              final columns = largeText
                  ? contentWidth >= 720
                        ? 2
                        : 1
                  : math.max(2, math.min(6, (contentWidth / 155).floor()));
              final rowCount = (stickerSpeciesIds.length / columns).ceil();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: rowCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: _ScrapbookHeader(earnedCount: earned.length),
                      ),
                    );
                  }
                  final first = (index - 1) * columns;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: contentWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0) const SizedBox(width: 12),
                              Expanded(
                                child: first + column < stickerSpeciesIds.length
                                    ? _StickerTile(
                                        speciesId:
                                            stickerSpeciesIds[first + column],
                                        pokemon: controller.speciesById(
                                          stickerSpeciesIds[first + column],
                                        ),
                                        isEarned: earned.containsKey(
                                          stickerSpeciesIds[first + column],
                                        ),
                                        onOpenPokemon: onOpenPokemon,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ScrapbookHeader extends StatelessWidget {
  const _ScrapbookHeader({required this.earnedCount});

  final int earnedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$earnedCount of 153 stickers found',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Semantics(
          label: '$earnedCount of 153 stickers found',
          excludeSemantics: true,
          child: LinearProgressIndicator(
            value: earnedCount / 153,
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Finish Today’s Adventure to uncover another friend.'),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.speciesId,
    required this.pokemon,
    required this.isEarned,
    required this.onOpenPokemon,
  });

  final int speciesId;
  final PokemonSpecies? pokemon;
  final bool isEarned;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  String get _dexLabel => '#${speciesId.toString().padLeft(4, '0')}';

  @override
  Widget build(BuildContext context) {
    final resolved = pokemon;
    final semanticsLabel = !isEarned
        ? 'Sticker $_dexLabel not collected'
        : resolved == null
        ? 'Earned sticker $_dexLabel is unavailable in this data version'
        : '${resolved.name} sticker collected';
    return Semantics(
      key: ValueKey('sticker-$speciesId'),
      container: true,
      button: isEarned && resolved != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: isEarned
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEarned && resolved != null
              ? () => onOpenPokemon(resolved)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEarned && resolved != null)
                  PokemonEmblem(pokemon: resolved, size: 92)
                else
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    child: Icon(
                      isEarned
                          ? Icons.image_not_supported_rounded
                          : Icons.catching_pokemon_rounded,
                      size: 42,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  isEarned && resolved != null
                      ? resolved.name
                      : isEarned
                      ? 'Sticker unavailable'
                      : 'Mystery sticker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 3),
                Text(_dexLabel),
                if (isEarned && resolved == null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Not in this data version',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
