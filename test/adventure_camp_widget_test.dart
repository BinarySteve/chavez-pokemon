import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/app.dart';
import 'package:pokemon_adventure/application/adventure_controller.dart';
import 'package:pokemon_adventure/domain/models/activity_progress.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/mini_adventure.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';
import 'package:pokemon_adventure/domain/models/trainer_profile.dart';
import 'package:pokemon_adventure/domain/repositories.dart';

void main() {
  testWidgets('daily adventure rewards completion after a gentle correction', (
    tester,
  ) async {
    _configurePhone(tester);
    final activities = _ActivityRepositoryFake();
    final controller = _controller(activities);

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Today’s mini adventure'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Today’s mini adventure'));
    await tester.pumpAndSettle();
    expect(find.text('Adventure Camp'), findsOneWidget);
    final adventure = controller.buildDailyAdventure();
    final guess = adventure.rounds[0] as PokemonGuessRound;
    final wrongGuess = guess.choices.firstWhere(
      (pokemon) => pokemon.id != guess.target.id,
    );

    await tester.tap(find.text('Start adventure'));
    await tester.pumpAndSettle();
    await _answer(tester, wrongGuess.name);
    expect(find.text('Good try!'), findsOneWidget);
    expect(find.text('It was ${guess.target.name}!'), findsOneWidget);
    await _continue(tester, 'Next round');

    final type = adventure.rounds[1] as TypePowerRound;
    await _answer(tester, type.correctType);
    expect(find.text('Great spotting!'), findsOneWidget);
    await _continue(tester, 'Next round');

    final evolution = adventure.rounds[2] as EvolutionTrailRound;
    await _answer(tester, evolution.to.name);
    await _continue(tester, 'Finish adventure');

    expect(find.text('Adventure complete!'), findsOneWidget);
    expect(
      find.text('You discovered a ${adventure.reward!.name} sticker!'),
      findsOneWidget,
    );
    expect(controller.activityProgress.earnedStickers, hasLength(1));
    expect(activities.saveCalls, 1);
  });

  testWidgets('Free Play never awards a sticker', (tester) async {
    _configurePhone(tester);
    final activities = _ActivityRepositoryFake();
    final controller = _controller(activities);
    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today’s mini adventure'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Free Play'));
    await tester.tap(find.text('Start Free Play'));
    await tester.pumpAndSettle();
    final adventure = controller.buildFreePlayAdventure();

    await _completeWithCorrectAnswers(tester, adventure);

    expect(find.text('Adventure complete!'), findsOneWidget);
    expect(find.textContaining('Free Play is always here'), findsOneWidget);
    expect(controller.activityProgress.earnedStickers, isEmpty);
    expect(activities.saveCalls, 0);
  });

  testWidgets('failed daily save offers retry without a false reward', (
    tester,
  ) async {
    _configurePhone(tester);
    final activities = _ActivityRepositoryFake()..failNextSave = true;
    final controller = _controller(activities);
    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today’s mini adventure'));
    await tester.pumpAndSettle();
    final adventure = controller.buildDailyAdventure();
    await tester.tap(find.text('Start adventure'));
    await tester.pumpAndSettle();

    await _completeWithCorrectAnswers(tester, adventure);

    expect(find.text('Adventure complete!'), findsNothing);
    expect(
      find.text(
        'We couldn’t save that sticker yet. Your progress is still safe.',
      ),
      findsOneWidget,
    );
    expect(controller.activityProgress.earnedStickers, isEmpty);
    await _continue(tester, 'Try saving again');
    expect(find.text('Adventure complete!'), findsOneWidget);
    expect(controller.activityProgress.earnedStickers, hasLength(1));
  });
}

Future<void> _completeWithCorrectAnswers(
  WidgetTester tester,
  MiniAdventure adventure,
) async {
  for (var index = 0; index < adventure.rounds.length; index++) {
    final round = adventure.rounds[index];
    final answer = switch (round) {
      PokemonGuessRound(:final target) => target.name,
      TypePowerRound(:final correctType) => correctType,
      EvolutionTrailRound(:final to) => to.name,
    };
    await _answer(tester, answer);
    await _continue(
      tester,
      index == adventure.rounds.length - 1 ? 'Finish adventure' : 'Next round',
    );
  }
}

Future<void> _answer(WidgetTester tester, String answer) async {
  await tester.ensureVisible(find.text(answer).last);
  await tester.tap(find.text(answer).last);
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void _configurePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AdventureController _controller(_ActivityRepositoryFake activities) {
  return AdventureController(
    referenceRepository: _ReferenceRepositoryFake(),
    userRepository: _UserRepositoryFake(),
    activityRepository: activities,
    updateService: _UpdateServiceFake(),
    clock: () => DateTime(2026, 7, 23, 12),
    freePlaySeed: () => 42,
  );
}

class _ReferenceRepositoryFake implements ReferenceRepository {
  @override
  Future<void> close() async {}

  @override
  Future<Map<String, String>> loadMetadata() async => {'dataset_version': '4'};

  @override
  Future<List<PokemonSpecies>> loadSpecies() async => [
    _pokemon(1, 'Bulbasaur', ['Grass', 'Poison'], evolvesTo: 2),
    _pokemon(2, 'Ivysaur', ['Grass', 'Poison']),
    _pokemon(4, 'Charmander', ['Fire'], evolvesTo: 5),
    _pokemon(5, 'Charmeleon', ['Fire']),
    _pokemon(7, 'Squirtle', ['Water'], evolvesTo: 8),
    _pokemon(8, 'Wartortle', ['Water']),
    _pokemon(25, 'Pikachu', ['Electric']),
  ];
}

PokemonSpecies _pokemon(
  int id,
  String name,
  List<String> types, {
  int? evolvesTo,
}) {
  return PokemonSpecies(
    id: id,
    dexNumber: id,
    name: name,
    classification: 'Fixture Pokémon',
    description: 'Fixture',
    heightMeters: 1,
    weightKilograms: 1,
    generation: 1,
    types: types,
    abilities: const [],
    forms: const [],
    evolutionEdges: [
      if (evolvesTo != null)
        EvolutionEdge(
          fromSpeciesId: id,
          toSpeciesId: evolvesTo,
          condition: 'Level up',
          sortOrder: 0,
        ),
    ],
  );
}

class _UserRepositoryFake implements UserRepository {
  @override
  Future<void> close() async {}

  @override
  Future<Map<int, CollectionState>> loadCollection() async => const {};

  @override
  Future<TrainerProfile?> loadProfile() async =>
      const TrainerProfile(name: 'Nova', avatar: 'star', partnerSpeciesId: 25);

  @override
  Future<void> saveCollectionState(CollectionState state) async {}

  @override
  Future<void> saveProfile(TrainerProfile profile) async {}
}

class _ActivityRepositoryFake implements ActivityRepository {
  ActivityProgress progress = ActivityProgress.empty;
  bool failNextSave = false;
  int saveCalls = 0;

  @override
  Future<ActivityProgress> loadActivityProgress() async => progress;

  @override
  Future<ActivityProgress> completeDailyAdventure(
    ActivityCompletion completion,
  ) async {
    saveCalls++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('simulated disk failure');
    }
    if (progress.hasCompleted(completion.activityId)) return progress;
    final completions = Map<String, ActivityCompletion>.of(progress.completions)
      ..[completion.activityId] = completion;
    final stickers = Map<int, EarnedSticker>.of(progress.earnedStickers);
    final reward = completion.rewardSpeciesId;
    if (reward != null) {
      stickers[reward] = EarnedSticker(
        speciesId: reward,
        sourceActivityId: completion.activityId,
        earnedAt: completion.completedAt,
      );
    }
    return progress = ActivityProgress(
      completions: Map.unmodifiable(completions),
      earnedStickers: Map.unmodifiable(stickers),
    );
  }
}

class _UpdateServiceFake implements UpdateService {
  @override
  Future<UpdateCheckResult> check({required int currentDatasetVersion}) async {
    return const UpdateCheckResult(
      state: UpdateCheckState.current,
      message: 'Current',
    );
  }
}
