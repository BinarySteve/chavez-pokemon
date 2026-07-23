import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/data/sqlite_reference_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('bundled reference database passes core semantic checks', () async {
    final file = File('assets/content/demo_reference.sqlite');
    expect(await file.exists(), isTrue);
    final manifest =
        jsonDecode(
              await File('assets/content/demo_manifest.json').readAsString(),
            )
            as Map<String, dynamic>;

    final repository = SqliteReferenceRepository(file.absolute.path);
    addTearDown(repository.close);
    final database = await databaseFactory.openDatabase(
      file.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(database.close);

    final metadata = await repository.loadMetadata();
    final species = await repository.loadSpecies();

    expect(manifest['manifestVersion'], 1);
    expect(manifest['datasetVersion'].toString(), metadata['dataset_version']);
    expect(manifest['contentSchema'].toString(), metadata['content_schema']);
    expect(manifest['displayName'], metadata['display_name']);
    expect(
      manifest['productionApproved'].toString(),
      metadata['production_approved'],
    );
    expect(manifest['datasetVersion'], 4);
    expect(manifest['productionApproved'], isFalse);

    final integrity = await database.rawQuery('PRAGMA integrity_check');
    expect(integrity.single.values.single, 'ok');
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(await _rowCount(database, 'species'), 1025);
    expect(await _rowCount(database, 'forms'), 200);
    expect(await _rowCount(database, 'evolution_edges'), 484);
    expect(await _rowCount(database, 'species_moves'), 68736);

    expect(species, hasLength(1025));
    expect(
      species.map((pokemon) => pokemon.dexNumber).toSet(),
      hasLength(species.length),
    );
    expect(species.every((pokemon) => pokemon.types.isNotEmpty), isTrue);
    for (final pokemon in species) {
      final artwork = File('assets/artwork/${pokemon.dexNumber}.png');
      expect(
        artwork.existsSync(),
        isTrue,
        reason: 'Missing base artwork for ${pokemon.name}',
      );
      expect(
        _hasPngSignature(artwork),
        isTrue,
        reason: 'Invalid PNG signature for ${pokemon.name}',
      );
    }

    final forms = species.expand((pokemon) => pokemon.forms).toList();
    expect(forms, hasLength(200));
    expect(forms.every((form) => form.artworkAsset.isNotEmpty), isTrue);
    for (final form in forms) {
      final artwork = File(form.artworkAsset);
      expect(
        artwork.existsSync(),
        isTrue,
        reason: 'Missing artwork for ${form.name}',
      );
      expect(
        _hasPngSignature(artwork),
        isTrue,
        reason: 'Invalid PNG signature for ${form.name}',
      );
    }

    final baseArtwork = Directory('assets/artwork')
        .listSync()
        .whereType<File>()
        .where((entry) => entry.path.toLowerCase().endsWith('.png'));
    final formArtwork = Directory('assets/form_artwork')
        .listSync()
        .whereType<File>()
        .where((entry) => entry.path.toLowerCase().endsWith('.png'));
    expect(baseArtwork, hasLength(1025));
    expect(formArtwork, hasLength(200));
  });

  test(
    'reference database represents forms and branching evolutions',
    () async {
      final repository = SqliteReferenceRepository(
        File('assets/content/demo_reference.sqlite').absolute.path,
      );
      addTearDown(repository.close);
      final species = await repository.loadSpecies();

      final charizard = species.singleWhere((pokemon) => pokemon.id == 6);
      expect(
        charizard.forms.map((form) => form.name),
        contains('Mega Charizard X'),
      );
      expect(
        charizard.forms.map((form) => form.name),
        contains('Mega Charizard Y'),
      );

      final eevee = species.singleWhere((pokemon) => pokemon.id == 133);
      final outgoing = eevee.evolutionEdges.where(
        (edge) => edge.fromSpeciesId == eevee.id,
      );
      expect(outgoing, hasLength(8));
    },
  );
}

Future<int> _rowCount(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count']! as int;
}

bool _hasPngSignature(File file) {
  final handle = file.openSync();
  try {
    const expected = [137, 80, 78, 71, 13, 10, 26, 10];
    final actual = handle.readSync(expected.length);
    if (actual.length != expected.length) {
      return false;
    }
    for (var index = 0; index < expected.length; index++) {
      if (actual[index] != expected[index]) {
        return false;
      }
    }
    return true;
  } finally {
    handle.closeSync();
  }
}
