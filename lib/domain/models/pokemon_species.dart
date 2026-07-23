import 'package:flutter/foundation.dart';

@immutable
class PokemonForm {
  const PokemonForm({
    required this.id,
    required this.name,
    required this.category,
    required this.types,
    required this.note,
    required this.isBattleOnly,
    this.artworkAsset = '',
  });

  final String id;
  final String name;
  final String category;
  final List<String> types;
  final String note;
  final bool isBattleOnly;
  final String artworkAsset;
}

@immutable
class EvolutionEdge {
  const EvolutionEdge({
    required this.fromSpeciesId,
    required this.toSpeciesId,
    required this.condition,
    required this.sortOrder,
  });

  final int fromSpeciesId;
  final int toSpeciesId;
  final String condition;
  final int sortOrder;
}

@immutable
class PokemonMove {
  const PokemonMove({
    required this.name,
    required this.type,
    required this.learnMethod,
    required this.levelLearned,
  });

  final String name;
  final String type;
  final String learnMethod;
  final int levelLearned;
}

@immutable
class PokemonSpecies {
  const PokemonSpecies({
    required this.id,
    required this.dexNumber,
    required this.name,
    required this.classification,
    required this.description,
    required this.heightMeters,
    required this.weightKilograms,
    required this.generation,
    required this.types,
    required this.abilities,
    required this.forms,
    required this.evolutionEdges,
    this.baseStats = const {},
    this.moves = const [],
  });

  final int id;
  final int dexNumber;
  final String name;
  final String classification;
  final String description;
  final double heightMeters;
  final double weightKilograms;
  final int generation;
  final List<String> types;
  final List<String> abilities;
  final List<PokemonForm> forms;
  final List<EvolutionEdge> evolutionEdges;
  final Map<String, int> baseStats;
  final List<PokemonMove> moves;

  String get dexLabel => '#${dexNumber.toString().padLeft(4, '0')}';

  String get normalizedSearchText {
    final formNames = forms.map((form) => form.name).join(' ');
    return _normalize('$name $dexNumber $dexLabel $formNames');
  }

  bool matches(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return true;
    }
    if (normalizedSearchText.contains(normalized)) {
      return true;
    }
    return _boundedDistance(_normalize(name), normalized) <= 1;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int _boundedDistance(String left, String right) {
    if ((left.length - right.length).abs() > 1) {
      return 2;
    }
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var row = 1; row <= left.length; row++) {
      final current = <int>[row];
      var rowMinimum = row;
      for (var column = 1; column <= right.length; column++) {
        final substitution =
            previous[column - 1] +
            (left.codeUnitAt(row - 1) == right.codeUnitAt(column - 1) ? 0 : 1);
        final value = [
          previous[column] + 1,
          current[column - 1] + 1,
          substitution,
        ].reduce((a, b) => a < b ? a : b);
        current.add(value);
        if (value < rowMinimum) {
          rowMinimum = value;
        }
      }
      if (rowMinimum > 1) {
        return 2;
      }
      previous = current;
    }
    return previous.last;
  }
}
