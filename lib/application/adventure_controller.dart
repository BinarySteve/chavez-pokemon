import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/collection_state.dart';
import '../domain/models/encounter_guide.dart';
import '../domain/models/pokemon_species.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/repositories.dart';

class AdventureController extends ChangeNotifier {
  AdventureController({
    required this.referenceRepository,
    required this.userRepository,
    required this.updateService,
    EncounterGuideRepository? encounterGuideRepository,
  }) : encounterGuideRepository =
           encounterGuideRepository ?? const _EmptyEncounterGuideRepository();

  final ReferenceRepository referenceRepository;
  final UserRepository userRepository;
  final UpdateService updateService;
  final EncounterGuideRepository encounterGuideRepository;

  List<PokemonSpecies> _species = const [];
  Map<int, CollectionState> _collection = const {};
  Map<String, String> _metadata = const {};
  TrainerProfile? _profile;
  UpdateCheckResult _updateResult = const UpdateCheckResult(
    state: UpdateCheckState.disabled,
    message: 'Update check has not run.',
  );
  Object? _error;
  bool _isReady = false;
  EncounterGuide _encounterGuide = EncounterGuide.empty;
  final Set<int> _pendingCollectionUpdates = {};

  List<PokemonSpecies> get species => _species;
  TrainerProfile? get profile => _profile;
  Map<String, String> get metadata => _metadata;
  UpdateCheckResult get updateResult => _updateResult;
  Object? get error => _error;
  bool get isReady => _isReady;
  bool get needsOnboarding => _profile == null;
  EncounterGuide get encounterGuide => _encounterGuide;

  bool isCollectionUpdatePending(int speciesId) =>
      _pendingCollectionUpdates.contains(speciesId);

  int get datasetVersion =>
      int.tryParse(_metadata['dataset_version'] ?? '') ?? 0;

  PokemonSpecies? get partner {
    final partnerId = _profile?.partnerSpeciesId;
    if (partnerId == null) {
      return null;
    }
    return speciesById(partnerId);
  }

  int get seenCount => _collection.values.where((state) => state.isSeen).length;
  int get caughtCount =>
      _collection.values.where((state) => state.isCaught).length;
  int get favoriteCount =>
      _collection.values.where((state) => state.isFavorite).length;

  Future<void> initialize() async {
    try {
      final results = await Future.wait<Object?>([
        referenceRepository.loadSpecies(),
        referenceRepository.loadMetadata(),
        userRepository.loadProfile().then<Object?>((value) => value),
        userRepository.loadCollection(),
      ]);
      _species = results[0] as List<PokemonSpecies>;
      _metadata = results[1] as Map<String, String>;
      _profile = results[2] as TrainerProfile?;
      _collection = results[3] as Map<int, CollectionState>;
      _isReady = true;
      notifyListeners();
      unawaited(_loadEncounterGuide());
      unawaited(checkForUpdates());
    } on Object catch (error) {
      _error = error;
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> _loadEncounterGuide() async {
    try {
      _encounterGuide = await encounterGuideRepository.load();
      notifyListeners();
    } on Object {
      _encounterGuide = EncounterGuide.empty;
    }
  }

  PokemonSpecies? speciesById(int id) {
    for (final pokemon in _species) {
      if (pokemon.id == id) {
        return pokemon;
      }
    }
    return null;
  }

  CollectionState collectionFor(int speciesId) {
    return _collection[speciesId] ?? CollectionState(speciesId: speciesId);
  }

  Future<void> completeOnboarding({
    required String trainerName,
    required String avatar,
    required int partnerSpeciesId,
  }) async {
    final profile = TrainerProfile(
      name: trainerName.trim(),
      avatar: avatar,
      partnerSpeciesId: partnerSpeciesId,
    );
    await userRepository.saveProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  Future<void> updateCollection(CollectionState state) async {
    if (_pendingCollectionUpdates.contains(state.speciesId)) {
      return;
    }
    _pendingCollectionUpdates.add(state.speciesId);
    notifyListeners();
    try {
      await userRepository.saveCollectionState(state);
      final updated = Map<int, CollectionState>.of(_collection)
        ..[state.speciesId] = state;
      _collection = Map.unmodifiable(updated);
    } finally {
      _pendingCollectionUpdates.remove(state.speciesId);
      notifyListeners();
    }
  }

  Future<void> checkForUpdates() async {
    _updateResult = const UpdateCheckResult(
      state: UpdateCheckState.checking,
      message: 'Checking bundled Pokédex data…',
    );
    notifyListeners();
    _updateResult = await updateService.check(
      currentDatasetVersion: datasetVersion,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(referenceRepository.close());
    unawaited(userRepository.close());
    super.dispose();
  }
}

class _EmptyEncounterGuideRepository implements EncounterGuideRepository {
  const _EmptyEncounterGuideRepository();

  @override
  Future<EncounterGuide> load() async => EncounterGuide.empty;
}
