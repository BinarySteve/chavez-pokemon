import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/repositories.dart';

class BundledUpdateService implements UpdateService {
  @override
  Future<UpdateCheckResult> check({required int currentDatasetVersion}) async {
    try {
      final source = await rootBundle.loadString(
        'assets/content/demo_manifest.json',
      );
      final manifest = jsonDecode(source) as Map<String, dynamic>;
      if (manifest['manifestVersion'] != 1 || manifest['contentSchema'] != 1) {
        throw const FormatException('Unsupported content manifest.');
      }
      final available = manifest['datasetVersion']! as int;
      if (available > currentDatasetVersion) {
        return UpdateCheckResult(
          state: UpdateCheckState.updateAvailable,
          message: 'New Pokédex content is ready for parent review.',
          availableDatasetVersion: available,
        );
      }
      return const UpdateCheckResult(
        state: UpdateCheckState.current,
        message: 'National Pokédex data is current.',
      );
    } on Object {
      return const UpdateCheckResult(
        state: UpdateCheckState.failed,
        message: 'Update check failed. Local adventure remains available.',
      );
    }
  }
}
