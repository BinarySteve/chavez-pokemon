import 'package:flutter/foundation.dart';

enum LetsGoVersion { pikachu, eevee }

@immutable
class LetsGoEncounterArea {
  const LetsGoEncounterArea({
    required this.id,
    required this.displayName,
    required this.requiredBadges,
  });

  final int id;
  final String displayName;
  final int requiredBadges;
}

@immutable
class LetsGoEncounter {
  const LetsGoEncounter({
    required this.speciesId,
    required this.areaId,
    required this.versions,
    required this.method,
    required this.minLevel,
    required this.maxLevel,
    required this.slotRarity,
    required this.conditions,
  });

  final int speciesId;
  final int areaId;
  final List<LetsGoVersion> versions;
  final String method;
  final int minLevel;
  final int maxLevel;
  final int slotRarity;
  final List<String> conditions;
}

@immutable
class EncounterGuide {
  const EncounterGuide({
    required this.guideSchemaVersion,
    required this.guideVersion,
    required this.logicalSha256,
    required this.areas,
    required this.encounters,
  });

  static const empty = EncounterGuide(
    guideSchemaVersion: 1,
    guideVersion: 0,
    logicalSha256: '',
    areas: {},
    encounters: [],
  );

  final int guideSchemaVersion;
  final int guideVersion;
  final String logicalSha256;
  final Map<int, LetsGoEncounterArea> areas;
  final List<LetsGoEncounter> encounters;

  bool get isAvailable => areas.isNotEmpty && encounters.isNotEmpty;
}
