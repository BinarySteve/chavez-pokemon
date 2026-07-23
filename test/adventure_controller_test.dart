import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/application/adventure_controller.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/encounter_guide.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';
import 'package:pokemon_adventure/domain/models/trainer_profile.dart';
import 'package:pokemon_adventure/domain/repositories.dart';

void main() {
  test('collection state changes only after persistence succeeds', () async {
    final user = _UserRepositoryFake();
    final controller = _controller(user);
    addTearDown(controller.dispose);
    await controller.initialize();
    user.saveCompleter = Completer<void>();

    final saving = controller.updateCollection(
      const CollectionState(speciesId: 25, isCaught: true),
    );

    expect(controller.isCollectionUpdatePending(25), isTrue);
    expect(controller.collectionFor(25).isCaught, isFalse);
    user.saveCompleter!.complete();
    await saving;
    expect(controller.isCollectionUpdatePending(25), isFalse);
    expect(controller.collectionFor(25).isCaught, isTrue);
  });

  test('failed collection save preserves last persisted state', () async {
    final user = _UserRepositoryFake(
      collection: const {25: CollectionState(speciesId: 25, isSeen: true)},
    )..saveError = StateError('disk full');
    final controller = _controller(user);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.updateCollection(
        const CollectionState(speciesId: 25, isSeen: true, isCaught: true),
      ),
      throwsStateError,
    );

    expect(controller.isCollectionUpdatePending(25), isFalse);
    expect(controller.collectionFor(25).isSeen, isTrue);
    expect(controller.collectionFor(25).isCaught, isFalse);
  });

  test(
    'duplicate interaction is ignored while species save is pending',
    () async {
      final user = _UserRepositoryFake()..saveCompleter = Completer<void>();
      final controller = _controller(user);
      addTearDown(controller.dispose);
      await controller.initialize();

      final first = controller.updateCollection(
        const CollectionState(speciesId: 25, isSeen: true),
      );
      await controller.updateCollection(
        const CollectionState(speciesId: 25, isCaught: true),
      );
      expect(user.saveCalls, 1);
      user.saveCompleter!.complete();
      await first;

      expect(controller.collectionFor(25).isSeen, isTrue);
      expect(controller.collectionFor(25).isCaught, isFalse);
    },
  );

  test('encounter guide failure never blocks core readiness', () async {
    final controller = AdventureController(
      referenceRepository: _ReferenceRepositoryFake(),
      userRepository: _UserRepositoryFake(),
      updateService: _UpdateServiceFake(),
      encounterGuideRepository: _FailingEncounterGuideRepository(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isReady, isTrue);
    expect(controller.error, isNull);
    expect(controller.encounterGuide, EncounterGuide.empty);
  });
}

AdventureController _controller(_UserRepositoryFake user) {
  return AdventureController(
    referenceRepository: _ReferenceRepositoryFake(),
    userRepository: user,
    updateService: _UpdateServiceFake(),
  );
}

class _ReferenceRepositoryFake implements ReferenceRepository {
  @override
  Future<void> close() async {}

  @override
  Future<Map<String, String>> loadMetadata() async => {'dataset_version': '4'};

  @override
  Future<List<PokemonSpecies>> loadSpecies() async => const [];
}

class _UserRepositoryFake implements UserRepository {
  _UserRepositoryFake({this.collection = const {}});

  final Map<int, CollectionState> collection;
  Completer<void>? saveCompleter;
  Object? saveError;
  int saveCalls = 0;

  @override
  Future<void> close() async {}

  @override
  Future<Map<int, CollectionState>> loadCollection() async => collection;

  @override
  Future<TrainerProfile?> loadProfile() async => null;

  @override
  Future<void> saveCollectionState(CollectionState state) async {
    saveCalls++;
    if (saveError case final error?) {
      throw error;
    }
    await saveCompleter?.future;
  }

  @override
  Future<void> saveProfile(TrainerProfile profile) async {}
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

class _FailingEncounterGuideRepository implements EncounterGuideRepository {
  @override
  Future<EncounterGuide> load() async => throw const FormatException('bad');
}
