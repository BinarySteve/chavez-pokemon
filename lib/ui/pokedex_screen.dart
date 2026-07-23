import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';
import 'widgets/type_badge.dart';

enum CollectionFilter { all, favorites, seen, caught, shiny, wantsToFind }

enum PokedexScope { all, letsGo }

class PokedexScreen extends StatefulWidget {
  const PokedexScreen({
    required this.controller,
    required this.onOpenPokemon,
    super.key,
  });

  final AdventureController controller;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _type;
  int? _generation;
  PokedexScope _scope = PokedexScope.all;
  CollectionFilter _collectionFilter = CollectionFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allTypes =
            widget.controller.species
                .expand((pokemon) => pokemon.types)
                .toSet()
                .toList()
              ..sort();
        final generations =
            widget.controller.species
                .map((pokemon) => pokemon.generation)
                .toSet()
                .toList()
              ..sort();
        final results = widget.controller.species
            .where((pokemon) {
              if (_scope == PokedexScope.letsGo &&
                  !_isLetsGoSpecies(pokemon.id)) {
                return false;
              }
              if (!pokemon.matches(_query)) {
                return false;
              }
              if (_type != null && !pokemon.types.contains(_type)) {
                return false;
              }
              if (_generation != null && pokemon.generation != _generation) {
                return false;
              }
              final state = widget.controller.collectionFor(pokemon.id);
              return switch (_collectionFilter) {
                CollectionFilter.all => true,
                CollectionFilter.favorites => state.isFavorite,
                CollectionFilter.seen => state.isSeen,
                CollectionFilter.caught => state.isCaught,
                CollectionFilter.shiny => state.isShiny,
                CollectionFilter.wantsToFind => state.wantsToFind,
              };
            })
            .toList(growable: false);

        return CustomScrollView(
          key: const PageStorageKey('pokedex-scroll'),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: const Text('Pokédex'),
              actions: [
                IconButton(
                  tooltip: 'More filters',
                  onPressed: () => _showFilters(
                    context,
                    types: allTypes,
                    generations: generations,
                  ),
                  icon: Badge(
                    isLabelVisible:
                        _type != null ||
                        _generation != null ||
                        _collectionFilter != CollectionFilter.all,
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        const SizedBox(height: 12),
                        SegmentedButton<PokedexScope>(
                          segments: const [
                            ButtonSegment(
                              value: PokedexScope.all,
                              icon: Icon(Icons.public_rounded),
                              label: Text('All Pokémon'),
                            ),
                            ButtonSegment(
                              value: PokedexScope.letsGo,
                              icon: Icon(Icons.videogame_asset_rounded),
                              label: Text('Let’s Go'),
                            ),
                          ],
                          selected: {_scope},
                          onSelectionChanged: (value) {
                            setState(() => _scope = value.single);
                          },
                        ),
                        const SizedBox(height: 12),
                        _ActiveFilters(
                          type: _type,
                          generation: _generation,
                          collectionFilter: _collectionFilter,
                          onClearType: () => setState(() => _type = null),
                          onClearGeneration: () =>
                              setState(() => _generation = null),
                          onClearCollection: () => setState(
                            () => _collectionFilter = CollectionFilter.all,
                          ),
                        ),
                        Text(
                          '${results.length} Pokémon shown',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _NoResults(
                  onReset: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _type = null;
                      _generation = null;
                      _collectionFilter = CollectionFilter.all;
                      _scope = PokedexScope.all;
                    });
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 980
                        ? 4
                        : width >= 680
                        ? 3
                        : width >= 430
                        ? 2
                        : 1;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 2.15 : 0.96,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final pokemon = results[index];
                        return _PokemonCard(
                          pokemon: pokemon,
                          isFavorite: widget.controller
                              .collectionFor(pokemon.id)
                              .isFavorite,
                          onTap: () => widget.onOpenPokemon(pokemon),
                        );
                      }, childCount: results.length),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showFilters(
    BuildContext context, {
    required List<String> types,
    required List<int> generations,
  }) async {
    var draftType = _type;
    var draftGeneration = _generation;
    var draftCollection = _collectionFilter;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Find your next discovery',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Type',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Any type'),
                          selected: draftType == null,
                          onSelected: (_) =>
                              setModalState(() => draftType = null),
                        ),
                        for (final type in types)
                          ChoiceChip(
                            label: Text(type),
                            selected: draftType == type,
                            onSelected: (_) =>
                                setModalState(() => draftType = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generation',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Any generation'),
                          selected: draftGeneration == null,
                          onSelected: (_) =>
                              setModalState(() => draftGeneration = null),
                        ),
                        for (final generation in generations)
                          ChoiceChip(
                            label: Text('Generation $generation'),
                            selected: draftGeneration == generation,
                            onSelected: (_) => setModalState(
                              () => draftGeneration = generation,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Collection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CollectionFilter>(
                      initialValue: draftCollection,
                      decoration: const InputDecoration(
                        labelText: 'Show entries',
                      ),
                      items: [
                        for (final filter in CollectionFilter.values)
                          DropdownMenuItem(
                            value: filter,
                            child: Text(_filterLabel(filter)),
                          ),
                      ],
                      onChanged: (value) => setModalState(
                        () => draftCollection = value ?? CollectionFilter.all,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _type = draftType;
                          _generation = draftGeneration;
                          _collectionFilter = draftCollection;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Show results'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

bool _isLetsGoSpecies(int id) => id <= 151 || id == 808 || id == 809;

String _filterLabel(CollectionFilter filter) {
  return switch (filter) {
    CollectionFilter.all => 'All entries',
    CollectionFilter.favorites => 'Favorites',
    CollectionFilter.seen => 'Seen',
    CollectionFilter.caught => 'Caught',
    CollectionFilter.shiny => 'Shiny',
    CollectionFilter.wantsToFind => 'Want to find',
  };
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.type,
    required this.generation,
    required this.collectionFilter,
    required this.onClearType,
    required this.onClearGeneration,
    required this.onClearCollection,
  });

  final String? type;
  final int? generation;
  final CollectionFilter collectionFilter;
  final VoidCallback onClearType;
  final VoidCallback onClearGeneration;
  final VoidCallback onClearCollection;

  @override
  Widget build(BuildContext context) {
    if (type == null &&
        generation == null &&
        collectionFilter == CollectionFilter.all) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (type != null)
            InputChip(
              label: Text(type!),
              onDeleted: onClearType,
              deleteButtonTooltipMessage: 'Remove type filter',
            ),
          if (generation != null)
            InputChip(
              label: Text('Generation $generation'),
              onDeleted: onClearGeneration,
              deleteButtonTooltipMessage: 'Remove generation filter',
            ),
          if (collectionFilter != CollectionFilter.all)
            InputChip(
              label: Text(_filterLabel(collectionFilter)),
              onDeleted: onClearCollection,
              deleteButtonTooltipMessage: 'Remove collection filter',
            ),
        ],
      ),
    );
  }
}

class _PokemonCard extends StatelessWidget {
  const _PokemonCard({
    required this.pokemon,
    required this.isFavorite,
    required this.onTap,
  });

  final PokemonSpecies pokemon;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth > constraints.maxHeight;
              final details = Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: horizontal
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pokemon.dexLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (isFavorite) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                            semanticLabel: 'Favorite',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pokemon.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: horizontal
                          ? TextAlign.start
                          : TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: horizontal
                          ? WrapAlignment.start
                          : WrapAlignment.center,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final type in pokemon.types)
                          TypeBadge(type: type, compact: true),
                      ],
                    ),
                  ],
                ),
              );
              if (horizontal) {
                return Row(
                  children: [
                    PokemonEmblem(
                      pokemon: pokemon,
                      size: 78,
                      heroTag: 'pokemon-${pokemon.id}',
                    ),
                    const SizedBox(width: 16),
                    details,
                    const Icon(Icons.chevron_right_rounded),
                  ],
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PokemonEmblem(
                    pokemon: pokemon,
                    size: 82,
                    heroTag: 'pokemon-${pokemon.id}',
                  ),
                  const SizedBox(height: 12),
                  details,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_rounded, size: 56),
            const SizedBox(height: 16),
            Text(
              'No Pokémon found here yet.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Try another name or clear a filter.'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset search'),
            ),
          ],
        ),
      ),
    );
  }
}
