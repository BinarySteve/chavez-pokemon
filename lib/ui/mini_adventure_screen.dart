import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/mini_adventure.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';

class MiniAdventureScreen extends StatefulWidget {
  const MiniAdventureScreen({
    required this.controller,
    required this.adventure,
    required this.wasCompleted,
    required this.onOpenPokemon,
    super.key,
  });

  final AdventureController controller;
  final MiniAdventure adventure;
  final bool wasCompleted;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  State<MiniAdventureScreen> createState() => _MiniAdventureScreenState();
}

class _MiniAdventureScreenState extends State<MiniAdventureScreen> {
  int _roundIndex = 0;
  String? _selectedAnswer;
  bool _isFinishing = false;
  bool _isComplete = false;
  Object? _saveError;

  AdventureRound get _round => widget.adventure.rounds[_roundIndex];

  bool get _isCorrect => _selectedAnswer == _correctAnswer(_round);

  void _answer(String answer) {
    if (_selectedAnswer != null) return;
    setState(() => _selectedAnswer = answer);
  }

  Future<void> _continue() async {
    if (_roundIndex < widget.adventure.rounds.length - 1) {
      setState(() {
        _roundIndex++;
        _selectedAnswer = null;
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() {
      _isFinishing = true;
      _saveError = null;
    });
    try {
      if (widget.adventure.isDaily) {
        await widget.controller.completeDailyAdventure(widget.adventure);
      }
      if (mounted) setState(() => _isComplete = true);
    } on Object catch (error) {
      if (mounted) setState(() => _saveError = error);
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.adventure.isDaily ? 'Today’s Adventure' : 'Free Play',
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: MediaQuery.accessibleNavigationOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: _isComplete
              ? _CompletionView(
                  key: const ValueKey('complete'),
                  adventure: widget.adventure,
                  wasCompleted: widget.wasCompleted,
                  onOpenPokemon: widget.onOpenPokemon,
                )
              : _RoundView(
                  key: ValueKey(_roundIndex),
                  round: _round,
                  roundNumber: _roundIndex + 1,
                  totalRounds: widget.adventure.rounds.length,
                  selectedAnswer: _selectedAnswer,
                  isCorrect: _isCorrect,
                  isFinishing: _isFinishing,
                  saveError: _saveError,
                  onAnswer: _answer,
                  onContinue: _continue,
                ),
        ),
      ),
    );
  }
}

class _RoundView extends StatelessWidget {
  const _RoundView({
    required this.round,
    required this.roundNumber,
    required this.totalRounds,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.isFinishing,
    required this.saveError,
    required this.onAnswer,
    required this.onContinue,
    super.key,
  });

  final AdventureRound round;
  final int roundNumber;
  final int totalRounds;
  final String? selectedAnswer;
  final bool isCorrect;
  final bool isFinishing;
  final Object? saveError;
  final ValueChanged<String> onAnswer;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Round $roundNumber of $totalRounds',
                  excludeSemantics: true,
                  child: LinearProgressIndicator(
                    value: roundNumber / totalRounds,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Round $roundNumber of $totalRounds',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  round.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                _RoundPrompt(round: round, reveal: selectedAnswer != null),
                const SizedBox(height: 18),
                for (final answer in _answers(round)) ...[
                  _AnswerButton(
                    answer: answer,
                    selectedAnswer: selectedAnswer,
                    correctAnswer: _correctAnswer(round),
                    onPressed: () => onAnswer(answer),
                  ),
                  const SizedBox(height: 10),
                ],
                if (selectedAnswer != null) ...[
                  const SizedBox(height: 8),
                  _FeedbackCard(round: round, isCorrect: isCorrect),
                  if (saveError != null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'We couldn’t save that sticker yet. Your progress is still safe.',
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: isFinishing ? null : onContinue,
                    icon: isFinishing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      saveError != null
                          ? 'Try saving again'
                          : roundNumber == totalRounds
                          ? 'Finish adventure'
                          : 'Next round',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundPrompt extends StatelessWidget {
  const _RoundPrompt({required this.round, required this.reveal});

  final AdventureRound round;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            switch (round) {
              PokemonGuessRound(:final target) => Column(
                children: [
                  Semantics(
                    image: true,
                    label: reveal
                        ? 'Artwork of ${target.name}'
                        : 'Mystery Pokémon silhouette',
                    excludeSemantics: true,
                    child: ColorFiltered(
                      colorFilter: reveal
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            )
                          : const ColorFilter.mode(
                              Colors.black,
                              BlendMode.srcIn,
                            ),
                      child: Image.asset(
                        'assets/artwork/${target.dexNumber}.png',
                        width: 190,
                        height: 190,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reveal ? target.name : 'Who could it be?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              TypePowerRound(:final opponent) => Column(
                children: [
                  PokemonEmblem(pokemon: opponent, size: 150),
                  const SizedBox(height: 10),
                  Text(
                    'Which move type is strong against ${opponent.name}?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              EvolutionTrailRound(:final from) => Column(
                children: [
                  PokemonEmblem(pokemon: from, size: 150),
                  const SizedBox(height: 10),
                  Text(
                    'What does ${from.name} evolve into next?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.onPressed,
  });

  final String answer;
  final String? selectedAnswer;
  final String correctAnswer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final answered = selectedAnswer != null;
    final correct = answer == correctAnswer;
    final selected = answer == selectedAnswer;
    final icon = answered && correct
        ? Icons.check_circle_rounded
        : answered && selected
        ? Icons.favorite_rounded
        : Icons.radio_button_unchecked_rounded;
    return Semantics(
      button: true,
      label: answer,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: answered ? null : onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(48, 58),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: answered && correct
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
        icon: Icon(icon),
        label: Text(answer),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.round, required this.isCorrect});

  final AdventureRound round;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCorrect ? 'Great spotting!' : 'Good try!',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(_explanation(round)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.adventure,
    required this.wasCompleted,
    required this.onOpenPokemon,
    super.key,
  });

  final MiniAdventure adventure;
  final bool wasCompleted;
  final ValueChanged<PokemonSpecies> onOpenPokemon;

  @override
  Widget build(BuildContext context) {
    final reward = adventure.reward;
    final reduceMotion = MediaQuery.accessibleNavigationOf(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .8, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 54),
                  const SizedBox(height: 12),
                  Text(
                    'Adventure complete!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    !adventure.isDaily
                        ? 'Great exploring! Free Play is always here when you want another round.'
                        : reward == null
                        ? 'Amazing—you already found every sticker!'
                        : wasCompleted
                        ? 'That was a fun replay with ${reward.name}.'
                        : 'You discovered a ${reward.name} sticker!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (reward != null) ...[
                    const SizedBox(height: 20),
                    PokemonEmblem(pokemon: reward, size: 190),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => onOpenPokemon(reward),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text('Meet ${reward.name}'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('Back to Adventure Camp'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _answers(AdventureRound round) {
  return switch (round) {
    PokemonGuessRound(:final choices) => [
      for (final pokemon in choices) pokemon.name,
    ],
    TypePowerRound(:final choices) => choices,
    EvolutionTrailRound(:final choices) => [
      for (final pokemon in choices) pokemon.name,
    ],
  };
}

String _correctAnswer(AdventureRound round) {
  return switch (round) {
    PokemonGuessRound(:final target) => target.name,
    TypePowerRound(:final correctType) => correctType,
    EvolutionTrailRound(:final to) => to.name,
  };
}

String _explanation(AdventureRound round) {
  return switch (round) {
    PokemonGuessRound(:final target) => 'It was ${target.name}!',
    TypePowerRound(:final opponent, :final correctType, :final multiplier) =>
      '$correctType moves are strong against ${opponent.name}, so they do '
          '${_multiplier(multiplier)} damage.',
    EvolutionTrailRound(:final from, :final to) =>
      '${from.name} evolves into ${to.name}.',
  };
}

String _multiplier(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}×' : '$value×';
