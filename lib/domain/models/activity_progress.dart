import 'package:flutter/foundation.dart';

@immutable
class ActivityCompletion {
  const ActivityCompletion({
    required this.activityId,
    required this.activityDate,
    required this.rewardSpeciesId,
    required this.completedAt,
  });

  final String activityId;
  final String activityDate;
  final int? rewardSpeciesId;
  final DateTime completedAt;
}

@immutable
class EarnedSticker {
  const EarnedSticker({
    required this.speciesId,
    required this.sourceActivityId,
    required this.earnedAt,
  });

  final int speciesId;
  final String sourceActivityId;
  final DateTime earnedAt;
}

@immutable
class ActivityProgress {
  const ActivityProgress({
    required this.completions,
    required this.earnedStickers,
  });

  static const empty = ActivityProgress(completions: {}, earnedStickers: {});

  final Map<String, ActivityCompletion> completions;
  final Map<int, EarnedSticker> earnedStickers;

  bool hasCompleted(String activityId) => completions.containsKey(activityId);
  bool hasSticker(int speciesId) => earnedStickers.containsKey(speciesId);
}
