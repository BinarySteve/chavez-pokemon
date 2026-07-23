import 'package:flutter/foundation.dart';

@immutable
class CollectionState {
  const CollectionState({
    required this.speciesId,
    this.isFavorite = false,
    this.isSeen = false,
    this.isCaught = false,
    this.isShiny = false,
    this.wantsToFind = false,
  });

  final int speciesId;
  final bool isFavorite;
  final bool isSeen;
  final bool isCaught;
  final bool isShiny;
  final bool wantsToFind;

  CollectionState copyWith({
    bool? isFavorite,
    bool? isSeen,
    bool? isCaught,
    bool? isShiny,
    bool? wantsToFind,
  }) {
    return CollectionState(
      speciesId: speciesId,
      isFavorite: isFavorite ?? this.isFavorite,
      isSeen: isSeen ?? this.isSeen,
      isCaught: isCaught ?? this.isCaught,
      isShiny: isShiny ?? this.isShiny,
      wantsToFind: wantsToFind ?? this.wantsToFind,
    );
  }

  bool get hasAnyProgress =>
      isFavorite || isSeen || isCaught || isShiny || wantsToFind;
}
