import 'package:flutter/foundation.dart';

@immutable
class TrainerProfile {
  const TrainerProfile({
    required this.name,
    required this.avatar,
    required this.partnerSpeciesId,
  });

  final String name;
  final String avatar;
  final int partnerSpeciesId;
}
