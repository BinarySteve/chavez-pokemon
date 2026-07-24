import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models/collection_state.dart';
import '../domain/models/activity_progress.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/repositories.dart';

class SqliteUserRepository implements UserRepository, ActivityRepository {
  SqliteUserRepository({this.databasePathOverride});

  final String? databasePathOverride;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }
    final databasePath =
        databasePathOverride ??
        path.join(
          (await getApplicationSupportDirectory()).path,
          'user',
          'user.sqlite',
        );
    await Directory(path.dirname(databasePath)).create(recursive: true);
    _database = await openDatabase(
      databasePath,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTrainerTables(db);
        await _createActivityTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createActivityTables(db);
        }
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        throw UnsupportedError(
          'Trainer database downgrade from $oldVersion to $newVersion '
          'is not supported.',
        );
      },
    );
    return _database!;
  }

  static Future<void> _createTrainerTables(DatabaseExecutor db) async {
    await db.execute('''
          CREATE TABLE trainer_profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            trainer_name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            partner_species_id INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
    await db.execute('''
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

  static Future<void> _createActivityTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE activity_completions (
        activity_id TEXT PRIMARY KEY,
        activity_date TEXT NOT NULL,
        reward_species_id INTEGER,
        completed_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE earned_stickers (
        species_id INTEGER PRIMARY KEY,
        source_activity_id TEXT NOT NULL UNIQUE,
        earned_at TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<TrainerProfile?> loadProfile() async {
    final rows = await (await _db).query(
      'trainer_profile',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return TrainerProfile(
      name: row['trainer_name']! as String,
      avatar: row['avatar']! as String,
      partnerSpeciesId: row['partner_species_id']! as int,
    );
  }

  @override
  Future<void> saveProfile(TrainerProfile profile) async {
    await (await _db).insert('trainer_profile', {
      'id': 1,
      'trainer_name': profile.name,
      'avatar': profile.avatar,
      'partner_species_id': profile.partnerSpeciesId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<int, CollectionState>> loadCollection() async {
    final rows = await (await _db).query('collection_state');
    return {
      for (final row in rows)
        row['species_id']! as int: CollectionState(
          speciesId: row['species_id']! as int,
          isFavorite: (row['is_favorite']! as int) == 1,
          isSeen: (row['is_seen']! as int) == 1,
          isCaught: (row['is_caught']! as int) == 1,
          isShiny: (row['is_shiny']! as int) == 1,
          wantsToFind: (row['wants_to_find']! as int) == 1,
        ),
    };
  }

  @override
  Future<void> saveCollectionState(CollectionState state) async {
    await (await _db).insert('collection_state', {
      'species_id': state.speciesId,
      'is_favorite': state.isFavorite ? 1 : 0,
      'is_seen': state.isSeen ? 1 : 0,
      'is_caught': state.isCaught ? 1 : 0,
      'is_shiny': state.isShiny ? 1 : 0,
      'wants_to_find': state.wantsToFind ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<ActivityProgress> loadActivityProgress() async {
    return _loadActivityProgress(await _db);
  }

  @override
  Future<ActivityProgress> completeDailyAdventure(
    ActivityCompletion completion,
  ) async {
    return (await _db).transaction((transaction) async {
      final inserted = await transaction.insert('activity_completions', {
        'activity_id': completion.activityId,
        'activity_date': completion.activityDate,
        'reward_species_id': completion.rewardSpeciesId,
        'completed_at': completion.completedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rewardSpeciesId = completion.rewardSpeciesId;
      if (inserted != 0 && rewardSpeciesId != null) {
        await transaction.insert('earned_stickers', {
          'species_id': rewardSpeciesId,
          'source_activity_id': completion.activityId,
          'earned_at': completion.completedAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return _loadActivityProgress(transaction);
    });
  }

  static Future<ActivityProgress> _loadActivityProgress(
    DatabaseExecutor db,
  ) async {
    final completionRows = await db.query('activity_completions');
    final stickerRows = await db.query('earned_stickers');
    return ActivityProgress(
      completions: Map.unmodifiable({
        for (final row in completionRows)
          row['activity_id']! as String: ActivityCompletion(
            activityId: row['activity_id']! as String,
            activityDate: row['activity_date']! as String,
            rewardSpeciesId: row['reward_species_id'] as int?,
            completedAt: DateTime.parse(row['completed_at']! as String),
          ),
      }),
      earnedStickers: Map.unmodifiable({
        for (final row in stickerRows)
          row['species_id']! as int: EarnedSticker(
            speciesId: row['species_id']! as int,
            sourceActivityId: row['source_activity_id']! as String,
            earnedAt: DateTime.parse(row['earned_at']! as String),
          ),
      }),
    );
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
