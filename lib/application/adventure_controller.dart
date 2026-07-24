import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/collection_state.dart';
import '../domain/models/activity_progress.dart';
import '../domain/models/encounter_guide.dart';
import '../domain/models/mini_adventure.dart';
import '../domain/models/pokemon_species.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/repositories.dart';
import 'mini_adventure_service.dart';

enum AppUpdateActionState {
  idle,
  downloading,
  waitingForPermission,
  openingInstaller,
  failed,
}

class AdventureController extends ChangeNotifier {
  AdventureController({
    required this.referenceRepository,
    required this.userRepository,
    required this.updateService,
    EncounterGuideRepository? encounterGuideRepository,
    ActivityRepository? activityRepository,
    this.miniAdventureService = const MiniAdventureService(),
    DateTime Function()? clock,
    int Function()? freePlaySeed,
  }) : encounterGuideRepository =
           encounterGuideRepository ?? const _EmptyEncounterGuideRepository(),
       activityRepository =
           activityRepository ?? const _EmptyActivityRepository(),
       _clock = clock ?? DateTime.now,
       _freePlaySeed =
           freePlaySeed ?? (() => DateTime.now().microsecondsSinceEpoch);

  final ReferenceRepository referenceRepository;
  final UserRepository userRepository;
  final UpdateService updateService;
  final EncounterGuideRepository encounterGuideRepository;
  final ActivityRepository activityRepository;
  final MiniAdventureService miniAdventureService;
  final DateTime Function() _clock;
  final int Function() _freePlaySeed;

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
  ActivityProgress _activityProgress = ActivityProgress.empty;
  bool _isActivityReady = false;
  bool _isActivityCompletionPending = false;
  Object? _activityError;
  final Set<int> _pendingCollectionUpdates = {};
  AppUpdateActionState _appUpdateActionState = AppUpdateActionState.idle;
  double _appUpdateDownloadProgress = 0;
  String? _appUpdateActionMessage;
  String? _downloadedUpdatePath;

  List<PokemonSpecies> get species => _species;
  TrainerProfile? get profile => _profile;
  Map<String, String> get metadata => _metadata;
  UpdateCheckResult get updateResult => _updateResult;
  Object? get error => _error;
  bool get isReady => _isReady;
  bool get needsOnboarding => _profile == null;
  EncounterGuide get encounterGuide => _encounterGuide;
  ActivityProgress get activityProgress => _activityProgress;
  bool get isActivityReady => _isActivityReady;
  bool get isActivityCompletionPending => _isActivityCompletionPending;
  Object? get activityError => _activityError;
  AppUpdateActionState get appUpdateActionState => _appUpdateActionState;
  double get appUpdateDownloadProgress => _appUpdateDownloadProgress;
  String? get appUpdateActionMessage => _appUpdateActionMessage;
  String get todayActivityId =>
      'daily-v${MiniAdventureService.algorithmVersion}-'
      '${MiniAdventureService.formatLocalDate(_clock())}';
  bool get isTodayAdventureComplete =>
      _activityProgress.hasCompleted(todayActivityId);

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
      unawaited(loadActivityProgress());
      unawaited(checkForUpdates());
    } on Object catch (error) {
      _error = error;
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> loadActivityProgress() async {
    _isActivityReady = false;
    _activityError = null;
    notifyListeners();
    try {
      _activityProgress = await activityRepository.loadActivityProgress();
      _isActivityReady = true;
    } on Object catch (error) {
      _activityError = error;
    }
    notifyListeners();
  }

  MiniAdventure buildDailyAdventure() {
    if (!_isActivityReady) {
      throw StateError('Activity progress is not ready.');
    }
    return miniAdventureService.buildDaily(
      localDate: _clock(),
      species: _species,
      collection: _collection,
      partner: partner,
      progress: _activityProgress,
    );
  }

  MiniAdventure buildFreePlayAdventure() {
    return miniAdventureService.buildFreePlay(
      seed: _freePlaySeed(),
      species: _species,
      collection: _collection,
      partner: partner,
    );
  }

  Future<void> completeDailyAdventure(MiniAdventure adventure) async {
    if (!adventure.isDaily || _isActivityCompletionPending) return;
    _isActivityCompletionPending = true;
    notifyListeners();
    try {
      final completedAt = _clock();
      _activityProgress = await activityRepository.completeDailyAdventure(
        ActivityCompletion(
          activityId: adventure.id,
          activityDate: adventure.activityDate,
          rewardSpeciesId: adventure.reward?.id,
          completedAt: completedAt,
        ),
      );
    } finally {
      _isActivityCompletionPending = false;
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

  Future<void> changePartner(int partnerSpeciesId) async {
    final current = _profile;
    if (current == null) {
      throw StateError('A trainer profile is required to choose a partner.');
    }
    if (speciesById(partnerSpeciesId) == null) {
      throw ArgumentError.value(
        partnerSpeciesId,
        'partnerSpeciesId',
        'Partner must exist in the active Pokédex.',
      );
    }
    if (current.partnerSpeciesId == partnerSpeciesId) {
      return;
    }
    final updated = TrainerProfile(
      name: current.name,
      avatar: current.avatar,
      partnerSpeciesId: partnerSpeciesId,
    );
    await userRepository.saveProfile(updated);
    _profile = updated;
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

  Future<void> beginAppUpdate() async {
    final service = updateService;
    final release = _updateResult.release;
    if (service is! AppUpdateService || release == null) {
      _appUpdateActionState = AppUpdateActionState.failed;
      _appUpdateActionMessage = 'This update is not ready to download.';
      notifyListeners();
      return;
    }

    _appUpdateActionState = AppUpdateActionState.downloading;
    _appUpdateDownloadProgress = 0;
    _appUpdateActionMessage = 'Downloading the new adventure…';
    notifyListeners();
    try {
      var lastPublishedProgress = 0.0;
      _downloadedUpdatePath = await service.download(
        release,
        onProgress: (progress) {
          final safeProgress = progress.clamp(0.0, 1.0);
          if (safeProgress < 1 && safeProgress - lastPublishedProgress < 0.01) {
            return;
          }
          lastPublishedProgress = safeProgress;
          _appUpdateDownloadProgress = safeProgress;
          notifyListeners();
        },
      );
      await _requestDownloadedUpdateInstall(service);
    } on Object catch (error, stackTrace) {
      debugPrint('App update preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _appUpdateActionState = AppUpdateActionState.failed;
      _appUpdateActionMessage =
          'The update could not be prepared. Nothing changed—try again later.';
      notifyListeners();
    }
  }

  Future<void> continueAppUpdate() async {
    final service = updateService;
    if (service is! AppUpdateService || _downloadedUpdatePath == null) {
      await beginAppUpdate();
      return;
    }
    try {
      await _requestDownloadedUpdateInstall(service);
    } on Object catch (error, stackTrace) {
      debugPrint('App update installer launch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _appUpdateActionState = AppUpdateActionState.failed;
      _appUpdateActionMessage =
          'Android could not open the update. The current app is still safe.';
      notifyListeners();
    }
  }

  Future<void> _requestDownloadedUpdateInstall(AppUpdateService service) async {
    final request = await service.requestInstall(_downloadedUpdatePath!);
    switch (request) {
      case UpdateInstallRequest.launched:
        _appUpdateActionState = AppUpdateActionState.openingInstaller;
        _appUpdateActionMessage =
            'Finish the update on Android’s confirmation screen.';
        break;
      case UpdateInstallRequest.permissionNeeded:
        _appUpdateActionState = AppUpdateActionState.waitingForPermission;
        _appUpdateActionMessage =
            'A grown-up must allow installs from this app, then come back.';
        break;
    }
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

class _EmptyActivityRepository implements ActivityRepository {
  const _EmptyActivityRepository();

  @override
  Future<ActivityProgress> loadActivityProgress() async =>
      ActivityProgress.empty;

  @override
  Future<ActivityProgress> completeDailyAdventure(
    ActivityCompletion completion,
  ) async => ActivityProgress.empty;
}
