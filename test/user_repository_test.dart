import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/data/sqlite_user_repository.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/trainer_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('profile and collection survive repository reopen', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'pokemon-adventure-user-test-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final databasePath =
        '${temporary.path}${Platform.pathSeparator}user.sqlite';

    final first = SqliteUserRepository(databasePathOverride: databasePath);
    await first.saveProfile(
      const TrainerProfile(name: 'Nova', avatar: 'star', partnerSpeciesId: 133),
    );
    await first.saveCollectionState(
      const CollectionState(
        speciesId: 25,
        isFavorite: true,
        isSeen: true,
        wantsToFind: true,
      ),
    );
    await first.close();

    final reopened = SqliteUserRepository(databasePathOverride: databasePath);
    addTearDown(reopened.close);
    final profile = await reopened.loadProfile();
    final collection = await reopened.loadCollection();

    expect(profile?.name, 'Nova');
    expect(profile?.partnerSpeciesId, 133);
    expect(collection[25]?.isFavorite, isTrue);
    expect(collection[25]?.isSeen, isTrue);
    expect(collection[25]?.wantsToFind, isTrue);
  });
}
