import 'models/collection_state.dart';
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

enum UpdateCheckState { disabled, checking, current, updateAvailable, failed }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.state,
    required this.message,
    this.availableDatasetVersion,
  });

  final UpdateCheckState state;
  final String message;
  final int? availableDatasetVersion;
}

abstract interface class UpdateService {
  Future<UpdateCheckResult> check({required int currentDatasetVersion});
}
