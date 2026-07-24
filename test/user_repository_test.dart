import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/data/sqlite_user_repository.dart';
import 'package:pokemon_adventure/domain/models/activity_progress.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/trainer_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('profile, collection, and activity progress survive reopen', () async {
    final databasePath = await _temporaryDatabasePath();
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
    await first.completeDailyAdventure(_completion('daily-v1-2026-07-23', 25));
    await first.close();

    final reopened = SqliteUserRepository(databasePathOverride: databasePath);
    addTearDown(reopened.close);
    final profile = await reopened.loadProfile();
    final collection = await reopened.loadCollection();
    final activities = await reopened.loadActivityProgress();

    expect(profile?.name, 'Nova');
    expect(profile?.partnerSpeciesId, 133);
    expect(collection[25]?.isFavorite, isTrue);
    expect(collection[25]?.isSeen, isTrue);
    expect(collection[25]?.wantsToFind, isTrue);
    expect(activities.hasCompleted('daily-v1-2026-07-23'), isTrue);
    expect(activities.hasSticker(25), isTrue);
  });

  test('version 1 migrates without changing trainer progress', () async {
    final databasePath = await _temporaryDatabasePath();
    final legacy = await _createDatabase(databasePath, version: 1);
    await _createTrainerTables(legacy);
    await legacy.insert('trainer_profile', {
      'id': 1,
      'trainer_name': 'Nova',
      'avatar': 'leaf',
      'partner_species_id': 133,
      'updated_at': '2026-07-23T00:00:00Z',
    });
    await legacy.insert('collection_state', {
      'species_id': 25,
      'is_favorite': 1,
      'is_seen': 1,
      'is_caught': 1,
      'is_shiny': 0,
      'wants_to_find': 0,
      'updated_at': '2026-07-23T00:00:00Z',
    });
    await legacy.close();

    final repository = SqliteUserRepository(databasePathOverride: databasePath);
    addTearDown(repository.close);

    expect((await repository.loadProfile())?.name, 'Nova');
    expect((await repository.loadCollection())[25]?.isCaught, isTrue);
    expect(await repository.loadActivityProgress(), isA<ActivityProgress>());
    final migrated = await databaseFactory.openDatabase(databasePath);
    expect(await migrated.getVersion(), 2);
    await migrated.close();
  });

  test('daily completion is atomic and idempotent', () async {
    final databasePath = await _temporaryDatabasePath();
    final repository = SqliteUserRepository(databasePathOverride: databasePath);
    addTearDown(repository.close);
    final completion = _completion('daily-v1-2026-07-23', 25);

    final first = await repository.completeDailyAdventure(completion);
    final second = await repository.completeDailyAdventure(completion);

    expect(first.completions, hasLength(1));
    expect(first.earnedStickers, hasLength(1));
    expect(second.completions, hasLength(1));
    expect(second.earnedStickers, hasLength(1));
  });

  test('failed sticker insert rolls back completion', () async {
    final databasePath = await _temporaryDatabasePath();
    final database = await _createDatabase(databasePath, version: 2);
    await _createTrainerTables(database);
    await _createActivityTables(database);
    await database.execute('''
      CREATE TRIGGER reject_sticker
      BEFORE INSERT ON earned_stickers
      BEGIN
        SELECT RAISE(ABORT, 'simulated disk failure');
      END
    ''');
    await database.close();
    final repository = SqliteUserRepository(databasePathOverride: databasePath);
    addTearDown(repository.close);

    await expectLater(
      repository.completeDailyAdventure(_completion('daily-v1-2026-07-23', 25)),
      throwsA(anything),
    );

    final progress = await repository.loadActivityProgress();
    expect(progress.completions, isEmpty);
    expect(progress.earnedStickers, isEmpty);
  });

  test('unsupported downgrade leaves newer database untouched', () async {
    final databasePath = await _temporaryDatabasePath();
    final newer = await _createDatabase(databasePath, version: 3);
    await newer.execute('CREATE TABLE future_data (value TEXT NOT NULL)');
    await newer.insert('future_data', {'value': 'keep me'});
    await newer.close();
    final repository = SqliteUserRepository(databasePathOverride: databasePath);

    await expectLater(repository.loadProfile(), throwsA(anything));
    await repository.close();

    final reopened = await databaseFactory.openDatabase(databasePath);
    final version = await reopened.getVersion();
    final rows = await reopened.query('future_data', columns: ['value']);
    await reopened.close();
    expect(version, 3);
    expect(rows.single['value'], 'keep me');
  });

  test('failed migration preserves version 1 data', () async {
    final databasePath = await _temporaryDatabasePath();
    final legacy = await _createDatabase(databasePath, version: 1);
    await _createTrainerTables(legacy);
    await legacy.insert('trainer_profile', {
      'id': 1,
      'trainer_name': 'Nova',
      'avatar': 'star',
      'partner_species_id': 25,
      'updated_at': '2026-07-23T00:00:00Z',
    });
    await legacy.execute('CREATE TABLE activity_completions (broken TEXT)');
    await legacy.close();
    final repository = SqliteUserRepository(databasePathOverride: databasePath);

    await expectLater(repository.loadProfile(), throwsA(anything));
    await repository.close();

    final reopened = await databaseFactory.openDatabase(databasePath);
    final version = await reopened.getVersion();
    final rows = await reopened.query(
      'trainer_profile',
      columns: ['trainer_name'],
    );
    await reopened.close();
    expect(version, 1);
    expect(rows.single['trainer_name'], 'Nova');
  });
}

ActivityCompletion _completion(String id, int? rewardSpeciesId) {
  return ActivityCompletion(
    activityId: id,
    activityDate: '2026-07-23',
    rewardSpeciesId: rewardSpeciesId,
    completedAt: DateTime.utc(2026, 7, 23, 12),
  );
}

Future<String> _temporaryDatabasePath() async {
  final temporary = await Directory.systemTemp.createTemp(
    'pokemon-adventure-user-test-',
  );
  addTearDown(() => temporary.delete(recursive: true));
  return '${temporary.path}${Platform.pathSeparator}user.sqlite';
}

Future<Database> _createDatabase(String path, {required int version}) {
  return databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (database, version) async {},
    ),
  );
}

Future<void> _createTrainerTables(Database database) async {
  await database.execute('''
    CREATE TABLE trainer_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      trainer_name TEXT NOT NULL,
      avatar TEXT NOT NULL,
      partner_species_id INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE collection_state (
      species_id INTEGER PRIMARY KEY,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      is_seen INTEGER NOT NULL DEFAULT 0,
      is_caught INTEGER NOT NULL DEFAULT 0,
      is_shiny INTEGER NOT NULL DEFAULT 0,
      wants_to_find INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )
  ''');
}

Future<void> _createActivityTables(Database database) async {
  await database.execute('''
    CREATE TABLE activity_completions (
      activity_id TEXT PRIMARY KEY,
      activity_date TEXT NOT NULL,
      reward_species_id INTEGER,
      completed_at TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE earned_stickers (
      species_id INTEGER PRIMARY KEY,
      source_activity_id TEXT NOT NULL UNIQUE,
      earned_at TEXT NOT NULL
    )
  ''');
}
