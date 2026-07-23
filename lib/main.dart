import 'package:flutter/material.dart';

import 'app.dart';
import 'application/adventure_controller.dart';
import 'data/asset_encounter_guide_repository.dart';
import 'data/bundled_update_service.dart';
import 'data/content_storage.dart';
import 'data/sqlite_reference_repository.dart';
import 'data/sqlite_user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final databasePath = await ContentStorage().prepareActiveDatabase();
  final controller = AdventureController(
    referenceRepository: SqliteReferenceRepository(databasePath),
    userRepository: SqliteUserRepository(),
    updateService: BundledUpdateService(),
    encounterGuideRepository: AssetEncounterGuideRepository(),
  );
  runApp(AdventureApp(controller: controller));
}
