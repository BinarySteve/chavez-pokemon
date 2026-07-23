import 'dart:async';

import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/collection_state.dart';
import '../domain/models/pokemon_species.dart';
import '../domain/battle/type_matchups.dart';
import 'widgets/pokemon_emblem.dart';
import 'widgets/type_badge.dart';

class PokemonDetailScreen extends StatefulWidget {
  const PokemonDetailScreen({
    required this.controller,
    required this.pokemon,
    super.key,
  });

  final AdventureController controller;
  final PokemonSpecies pokemon;

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  @override
  void initState() {
    super.initState();
    final state = widget.controller.collectionFor(widget.pokemon.id);
    if (!state.isSeen) {
      unawaited(
        widget.controller.updateCollection(state.copyWith(isSeen: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pokemon = widget.pokemon;
        final collection = widget.controller.collectionFor(pokemon.id);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                pinned: true,
                title: Text(pokemon.name),
                actions: [
                  IconButton(
                    tooltip: collection.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    onPressed: () => widget.controller.updateCollection(
                      collection.copyWith(isFavorite: !collection.isFavorite),
                    ),
                    icon: Icon(
                      collection.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroCard(pokemon: pokemon),
                          const SizedBox(height: 18),
                          _CollectionCard(
                            state: collection,
                            onChanged: widget.controller.updateCollection,
                          ),
                          const SizedBox(height: 18),
                          _StoryCard(pokemon: pokemon),
                          const SizedBox(height: 18),
                          _WeaknessCard(pokemon: pokemon),
                          const SizedBox(height: 18),
                          _EvolutionCard(
                            controller: widget.controller,
                            pokemon: pokemon,
                            onOpen: _replaceWithPokemon,
                          ),
                          if (pokemon.forms.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _FormsCard(pokemon: pokemon),
                          ],
                          const SizedBox(height: 18),
                          _FactsCard(pokemon: pokemon),
                          if (pokemon.moves.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _MovesCard(pokemon: pokemon),
                          ],
                          const SizedBox(height: 18),
                          _DemoNotice(
                            datasetName:
                                widget.controller.metadata['display_name'] ??
                                'Pokédex content',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _replaceWithPokemon(PokemonSpecies pokemon) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => PokemonDetailScreen(
          controller: widget.controller,
          pokemon: pokemon,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 540;
            final emblem = PokemonEmblem(
              pokemon: pokemon,
              size: compact ? 130 : 170,
              heroTag: 'pokemon-${pokemon.id}',
            );
            final details = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  pokemon.dexLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  pokemon.name,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 4),
                Text(
                  pokemon.classification,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: compact
                      ? WrapAlignment.center
                      : WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in pokemon.types) TypeBadge(type: type),
                  ],
                ),
              ],
            );
            if (compact) {
              return Column(
                children: [emblem, const SizedBox(height: 18), details],
              );
            }
            return Row(
              children: [
                emblem,
                const SizedBox(width: 28),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.state, required this.onChanged});

  final CollectionState state;
  final ValueChanged<CollectionState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('My adventure', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CollectionToggle(
                  label: 'Seen',
                  icon: Icons.visibility_rounded,
                  selected: state.isSeen,
                  onSelected: (selected) =>
                      onChanged(state.copyWith(isSeen: selected)),
                ),
                _CollectionToggle(
                  label: 'Caught',
                  icon: Icons.check_circle_rounded,
                  selected: state.isCaught,
                  onSelected: (selected) =>
                      onChanged(state.copyWith(isCaught: selected)),
                ),
                _CollectionToggle(
                  label: 'Shiny',
                  icon: Icons.auto_awesome_rounded,
                  selected: state.isShiny,
                  onSelected: (selected) =>
                      onChanged(state.copyWith(isShiny: selected)),
                ),
                _CollectionToggle(
                  label: 'Want to find',
                  icon: Icons.flag_rounded,
                  selected: state.wantsToFind,
                  onSelected: (selected) =>
                      onChanged(state.copyWith(wantsToFind: selected)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionToggle extends StatelessWidget {
  const _CollectionToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(icon, size: 20),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Field notes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              pokemon.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({
    required this.controller,
    required this.pokemon,
    required this.onOpen,
  });

  final AdventureController controller;
  final PokemonSpecies pokemon;
  final ValueChanged<PokemonSpecies> onOpen;

  @override
  Widget build(BuildContext context) {
    if (pokemon.evolutionEdges.isEmpty) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Evolution'),
          subtitle: const Text(
            'No evolution path is included for this Pokémon.',
          ),
        ),
      );
    }
    final edges = [...pokemon.evolutionEdges]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Evolution paths',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final edge in edges)
              _EvolutionRoute(
                from: controller.speciesById(edge.fromSpeciesId)!,
                to: controller.speciesById(edge.toSpeciesId)!,
                condition: edge.condition,
                onOpen: onOpen,
              ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionRoute extends StatelessWidget {
  const _EvolutionRoute({
    required this.from,
    required this.to,
    required this.condition,
    required this.onOpen,
  });

  final PokemonSpecies from;
  final PokemonSpecies to;
  final String condition;
  final ValueChanged<PokemonSpecies> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _SpeciesLink(pokemon: from, onOpen: onOpen),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                const Icon(Icons.arrow_forward_rounded),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    condition,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _SpeciesLink(pokemon: to, onOpen: onOpen),
          ),
        ],
      ),
    );
  }
}

class _SpeciesLink extends StatelessWidget {
  const _SpeciesLink({required this.pokemon, required this.onOpen});

  final PokemonSpecies pokemon;
  final ValueChanged<PokemonSpecies> onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onOpen(pokemon),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            PokemonEmblem(pokemon: pokemon, size: 54),
            const SizedBox(height: 6),
            Text(
              pokemon.name,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormsCard extends StatelessWidget {
  const _FormsCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forms', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Tap a form to see its artwork and details.'),
            const SizedBox(height: 12),
            for (final form in pokemon.forms)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _FormTile(pokemon: pokemon, form: form),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.pokemon, required this.form});

  final PokemonSpecies pokemon;
  final PokemonForm form;

  String get _asset => form.artworkAsset.isEmpty
      ? 'assets/artwork/${pokemon.dexNumber}.png'
      : form.artworkAsset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'form-${pokemon.id}-${form.id}',
                child: Image.asset(
                  _asset,
                  width: 82,
                  height: 82,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/artwork/${pokemon.dexNumber}.png',
                    width: 82,
                    height: 82,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(form.category),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final type in form.types)
                          TypeBadge(type: type, compact: true),
                        if (form.isBattleOnly)
                          const Chip(label: Text('Battle only')),
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

  Future<void> _showDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'form-${pokemon.id}-${form.id}',
                child: SizedBox(
                  height: 300,
                  child: Image.asset(
                    _asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/artwork/${pokemon.dexNumber}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                form.name,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              Text(
                form.category,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in form.types) TypeBadge(type: type),
                  if (form.isBattleOnly) const Chip(label: Text('Battle only')),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                form.note,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick facts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 18,
              children: [
                _Fact(label: 'Height', value: '${pokemon.heightMeters} m'),
                _Fact(label: 'Weight', value: '${pokemon.weightKilograms} kg'),
                _Fact(label: 'Generation', value: '${pokemon.generation}'),
                if (pokemon.abilities.isNotEmpty)
                  _Fact(
                    label: 'Abilities (where used)',
                    value: pokemon.abilities.join(', '),
                  ),
                for (final stat in pokemon.baseStats.entries)
                  _Fact(label: _statLabel(stat.key), value: '${stat.value}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statLabel(String value) => switch (value) {
    'hp' => 'HP',
    'attack' => 'Attack',
    'defense' => 'Defense',
    'special-attack' => 'Sp. Attack',
    'special-defense' => 'Sp. Defense',
    'speed' => 'Speed',
    _ => value,
  };
}

class _MovesCard extends StatelessWidget {
  const _MovesCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    final levelMoves = pokemon.moves
        .where((move) => move.learnMethod == 'level-up')
        .toList();
    final otherMoves = pokemon.moves
        .where((move) => move.learnMethod != 'level-up')
        .toList();
    return Card(
      child: ExpansionTile(
        title: const Text('Moves'),
        subtitle: Text(
          '${pokemon.moves.length} learnable moves · availability varies by game',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (levelMoves.isNotEmpty) ...[
            Text(
              'By leveling up',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final move in levelMoves)
                  Chip(
                    avatar: TypeBadge(type: move.type, compact: true),
                    label: Text(
                      move.levelLearned == 0
                          ? '${move.name} · learned on evolution/start'
                          : '${move.name} · Lv. ${move.levelLearned}',
                    ),
                  ),
              ],
            ),
          ],
          if (otherMoves.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('TM or tutor', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final move in otherMoves)
                  Chip(
                    avatar: TypeBadge(type: move.type, compact: true),
                    label: Text(move.name),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeaknessCard extends StatelessWidget {
  const _WeaknessCard({required this.pokemon});

  final PokemonSpecies pokemon;

  @override
  Widget build(BuildContext context) {
    final entries = defensiveMatchups(pokemon.types).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final amazing = entries.where((entry) => entry.value >= 4).toList();
    final strong = entries
        .where((entry) => entry.value > 1 && entry.value < 4)
        .toList();
    final resisted =
        entries.where((entry) => entry.value > 0 && entry.value < 1).toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    final immune = entries.where((entry) => entry.value == 0).toList();
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How do I battle ${pokemon.name}?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a move type from “Best choices.” Those moves will hit harder!',
            ),
            const SizedBox(height: 16),
            _MatchupGroup(
              icon: Icons.auto_awesome_rounded,
              title: 'Best choices',
              explanation: 'Use these move types against ${pokemon.name}.',
              entries: [...amazing, ...strong],
              labelFor: (value) => value >= 4
                  ? 'Amazing! ${_multiplier(value)}'
                  : 'Strong! ${_multiplier(value)}',
            ),
            if (resisted.isNotEmpty) ...[
              const SizedBox(height: 18),
              _MatchupGroup(
                icon: Icons.shield_outlined,
                title: 'Not very helpful',
                explanation: 'These moves will not do much damage.',
                entries: resisted,
                labelFor: (value) => value <= .25
                    ? 'Very weak ${_multiplier(value)}'
                    : 'Weak ${_multiplier(value)}',
              ),
            ],
            if (immune.isNotEmpty) ...[
              const SizedBox(height: 18),
              _MatchupGroup(
                icon: Icons.block_rounded,
                title: 'Won’t work',
                explanation: 'These moves do no damage at all.',
                entries: immune,
                labelFor: (_) => 'No damage',
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check the move’s type—not only your Pokémon’s type. Level and stats matter too.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _multiplier(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}×' : '$value×';
}

class _MatchupGroup extends StatelessWidget {
  const _MatchupGroup({
    required this.icon,
    required this.title,
    required this.explanation,
    required this.entries,
    required this.labelFor,
  });

  final IconData icon;
  final String title;
  final String explanation;
  final List<MapEntry<String, double>> entries;
  final String Function(double) labelFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 3),
        Text(explanation),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              Semantics(
                label: '${entry.key}: ${labelFor(entry.value)}',
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: .68),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TypeBadge(type: entry.key, compact: true),
                      const SizedBox(width: 7),
                      Text(
                        labelFor(entry.value),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.datasetName});

  final String datasetName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.science_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$datasetName uses offline PokeAPI data. Pokémon artwork is © The Pokémon Company and included only for private family use.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
