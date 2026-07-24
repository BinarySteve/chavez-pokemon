import 'models/collection_state.dart';
import 'models/encounter_guide.dart';
import 'models/activity_progress.dart';
import 'models/pokemon_species.dart';
import 'models/trainer_profile.dart';

abstract interface class ReferenceRepository {
  Future<List<PokemonSpecies>> loadSpecies();

  Future<Map<String, String>> loadMetadata();

  Future<void> close();
}

abstract interface class UserRepository {
  Future<TrainerProfile?> loadProfile();

  Future<void> saveProfile(TrainerProfile profile);

  Future<Map<int, CollectionState>> loadCollection();

  Future<void> saveCollectionState(CollectionState state);

  Future<void> close();
}

abstract interface class EncounterGuideRepository {
  Future<EncounterGuide> load();
}

abstract interface class ActivityRepository {
  Future<ActivityProgress> loadActivityProgress();

  Future<ActivityProgress> completeDailyAdventure(
    ActivityCompletion completion,
  );
}

enum UpdateCheckState { disabled, checking, current, updateAvailable, failed }

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUri,
    required this.sha256,
    required this.sizeBytes,
    required this.title,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final Uri apkUri;
  final String sha256;
  final int sizeBytes;
  final String title;
  final List<String> notes;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.state,
    required this.message,
    this.availableDatasetVersion,
    this.release,
  });

  final UpdateCheckState state;
  final String message;
  final int? availableDatasetVersion;
  final AppUpdateRelease? release;
}

abstract interface class UpdateService {
  Future<UpdateCheckResult> check({required int currentDatasetVersion});
}

enum UpdateInstallRequest { launched, permissionNeeded }

abstract interface class AppUpdateService implements UpdateService {
  Future<String> download(
    AppUpdateRelease release, {
    required void Function(double progress) onProgress,
  });

  Future<UpdateInstallRequest> requestInstall(String apkPath);
}
