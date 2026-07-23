import 'package:sqflite/sqflite.dart';

import '../domain/models/pokemon_species.dart';
import '../domain/repositories.dart';

class SqliteReferenceRepository implements ReferenceRepository {
  SqliteReferenceRepository(this.databasePath);

  final String databasePath;
  Database? _database;

  Future<Database> get _db async {
    return _database ??= await openDatabase(databasePath, readOnly: true);
  }

  @override
  Future<Map<String, String>> loadMetadata() async {
    final rows = await (await _db).query('metadata');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  @override
  Future<List<PokemonSpecies>> loadSpecies() async {
    final database = await _db;
    final speciesRows = await database.query(
      'species',
      orderBy: 'dex_number ASC',
    );
    final typeRows = await database.query(
      'species_types',
      orderBy: 'species_id, slot',
    );
    final abilityRows = await database.query(
      'species_abilities',
      orderBy: 'species_id, slot',
    );
    final formRows = await database.query('forms', orderBy: 'name');
    final formTypeRows = await database.query(
      'form_types',
      orderBy: 'form_id, slot',
    );
    final evolutionRows = await database.query(
      'evolution_edges',
      orderBy: 'sort_order',
    );
    final statRows = await database.query(
      'species_stats',
      orderBy: 'species_id, stat_name',
    );
    final moveRows = await database.query(
      'species_moves',
      orderBy: 'species_id, level_learned, move_name',
    );

    final typesBySpecies = <int, List<String>>{};
    for (final row in typeRows) {
      typesBySpecies
          .putIfAbsent(row['species_id']! as int, () => [])
          .add(row['type_name']! as String);
    }

    final abilitiesBySpecies = <int, List<String>>{};
    for (final row in abilityRows) {
      abilitiesBySpecies
          .putIfAbsent(row['species_id']! as int, () => [])
          .add(row['ability_name']! as String);
    }

    final typesByForm = <String, List<String>>{};
    for (final row in formTypeRows) {
      typesByForm
          .putIfAbsent(row['form_id']! as String, () => [])
          .add(row['type_name']! as String);
    }

    final formsBySpecies = <int, List<PokemonForm>>{};
    for (final row in formRows) {
      final formId = row['id']! as String;
      formsBySpecies
          .putIfAbsent(row['species_id']! as int, () => [])
          .add(
            PokemonForm(
              id: formId,
              name: row['name']! as String,
              category: row['category']! as String,
              types: List.unmodifiable(typesByForm[formId] ?? const []),
              note: row['note']! as String,
              isBattleOnly: (row['is_battle_only']! as int) == 1,
              artworkAsset: row['artwork_asset']! as String,
            ),
          );
    }

    final edgesBySpecies = <int, List<EvolutionEdge>>{};
    for (final row in evolutionRows) {
      final edge = EvolutionEdge(
        fromSpeciesId: row['from_species_id']! as int,
        toSpeciesId: row['to_species_id']! as int,
        condition: row['condition_text']! as String,
        sortOrder: row['sort_order']! as int,
      );
      edgesBySpecies.putIfAbsent(edge.fromSpeciesId, () => []).add(edge);
      edgesBySpecies.putIfAbsent(edge.toSpeciesId, () => []).add(edge);
    }

    final statsBySpecies = <int, Map<String, int>>{};
    for (final row in statRows) {
      statsBySpecies.putIfAbsent(
        row['species_id']! as int,
        () => {},
      )[row['stat_name']! as String] = row['base_value']! as int;
    }

    final movesBySpecies = <int, List<PokemonMove>>{};
    for (final row in moveRows) {
      movesBySpecies
          .putIfAbsent(row['species_id']! as int, () => [])
          .add(
            PokemonMove(
              name: row['move_name']! as String,
              type: row['move_type']! as String,
              learnMethod: row['learn_method']! as String,
              levelLearned: row['level_learned']! as int,
            ),
          );
    }

    return List.unmodifiable(
      speciesRows.map(
        (row) => PokemonSpecies(
          id: row['id']! as int,
          dexNumber: row['dex_number']! as int,
          name: row['name']! as String,
          classification: row['classification']! as String,
          description: row['description']! as String,
          heightMeters: row['height_m']! as double,
          weightKilograms: row['weight_kg']! as double,
          generation: row['generation']! as int,
          types: List.unmodifiable(
            typesBySpecies[row['id']! as int] ?? const [],
          ),
          abilities: List.unmodifiable(
            abilitiesBySpecies[row['id']! as int] ?? const [],
          ),
          forms: List.unmodifiable(
            formsBySpecies[row['id']! as int] ?? const [],
          ),
          evolutionEdges: List.unmodifiable(
            edgesBySpecies[row['id']! as int] ?? const [],
          ),
          baseStats: Map.unmodifiable(
            statsBySpecies[row['id']! as int] ?? const {},
          ),
          moves: List.unmodifiable(
            movesBySpecies[row['id']! as int] ?? const [],
          ),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
