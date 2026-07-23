import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/data/asset_encounter_guide_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled encounter guide loads with audited coverage', () async {
    final guide = await AssetEncounterGuideRepository().load();

    expect(guide.guideSchemaVersion, 1);
    expect(guide.guideVersion, 1);
    expect(guide.areas, hasLength(65));
    expect(guide.encounters, hasLength(737));
    expect(
      guide.encounters.map((item) => item.speciesId).toSet(),
      hasLength(130),
    );
    expect(
      guide.logicalSha256,
      'e584656273c8327c1b6b34e8f62621bfad816d5b06ceb58c7c42d0afafd71b6b',
    );
  });

  test('malformed guide is rejected', () async {
    final repository = AssetEncounterGuideRepository(
      bundle: _StringAssetBundle('{"guideSchemaVersion":1}'),
    );

    await expectLater(repository.load(), throwsFormatException);
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
