import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/encounter_guide.dart';
import '../domain/repositories.dart';

class AssetEncounterGuideRepository implements EncounterGuideRepository {
  AssetEncounterGuideRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/guides/lets_go_encounters.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  @override
  Future<EncounterGuide> load() async {
    final decoded = jsonDecode(await _bundle.loadString(assetPath));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Encounter guide must be a JSON object.');
    }
    if (decoded['guideSchemaVersion'] != 1 || decoded['guideVersion'] != 1) {
      throw const FormatException('Unsupported encounter guide version.');
    }
    final logicalSha256 = decoded['logicalSha256'];
    if (logicalSha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(logicalSha256)) {
      throw const FormatException('Invalid encounter guide logical hash.');
    }

    final rawAreas = _list(decoded, 'areas');
    final areas = <int, LetsGoEncounterArea>{};
    for (final raw in rawAreas) {
      final area = _map(raw, 'area');
      final id = _positiveInt(area, 'id');
      final displayName = _nonEmptyString(area, 'displayName');
      final requiredBadges = _int(area, 'requiredBadges');
      if (requiredBadges < 0 || requiredBadges > 8 || areas.containsKey(id)) {
        throw const FormatException('Invalid encounter area.');
      }
      areas[id] = LetsGoEncounterArea(
        id: id,
        displayName: displayName,
        requiredBadges: requiredBadges,
      );
    }

    final encounters = <LetsGoEncounter>[];
    for (final raw in _list(decoded, 'encounters')) {
      final encounter = _map(raw, 'encounter');
      final areaId = _positiveInt(encounter, 'areaId');
      final minLevel = _positiveInt(encounter, 'minLevel');
      final maxLevel = _positiveInt(encounter, 'maxLevel');
      final slotRarity = _int(encounter, 'slotRarity');
      if (!areas.containsKey(areaId) || maxLevel < minLevel || slotRarity < 0) {
        throw const FormatException('Invalid encounter record.');
      }
      final versions = _list(encounter, 'versions')
          .map((value) {
            return switch (value) {
              'lets-go-pikachu' => LetsGoVersion.pikachu,
              'lets-go-eevee' => LetsGoVersion.eevee,
              _ => throw const FormatException('Unknown Let’s Go version.'),
            };
          })
          .toSet()
          .toList(growable: false);
      if (versions.isEmpty) {
        throw const FormatException('Encounter must name a game version.');
      }
      final conditions = _list(encounter, 'conditions')
          .map((value) {
            if (value is! String || value.isEmpty) {
              throw const FormatException('Invalid encounter condition.');
            }
            return value;
          })
          .toList(growable: false);
      encounters.add(
        LetsGoEncounter(
          speciesId: _positiveInt(encounter, 'speciesId'),
          areaId: areaId,
          versions: List.unmodifiable(versions),
          method: _nonEmptyString(encounter, 'method'),
          minLevel: minLevel,
          maxLevel: maxLevel,
          slotRarity: slotRarity,
          conditions: List.unmodifiable(conditions),
        ),
      );
    }
    if (areas.isEmpty || encounters.isEmpty) {
      throw const FormatException('Encounter guide cannot be empty.');
    }

    return EncounterGuide(
      guideSchemaVersion: 1,
      guideVersion: 1,
      logicalSha256: logicalSha256,
      areas: Map.unmodifiable(areas),
      encounters: List.unmodifiable(encounters),
    );
  }

  static List<dynamic> _list(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! List<dynamic>) {
      throw FormatException('$key must be a list.');
    }
    return result;
  }

  static Map<String, dynamic> _map(Object? value, String label) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$label must be an object.');
    }
    return value;
  }

  static int _int(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! int) {
      throw FormatException('$key must be an integer.');
    }
    return result;
  }

  static int _positiveInt(Map<String, dynamic> value, String key) {
    final result = _int(value, key);
    if (result <= 0) {
      throw FormatException('$key must be positive.');
    }
    return result;
  }

  static String _nonEmptyString(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! String || result.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return result;
  }
}
