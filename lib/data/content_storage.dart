import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ContentStorage {
  ContentStorage({this.rootOverride});

  final Directory? rootOverride;

  static const _bundledDatabaseAsset = 'assets/content/demo_reference.sqlite';

  Future<String> prepareActiveDatabase() async {
    final root = rootOverride ?? await getApplicationSupportDirectory();
    final contentRoot = Directory(path.join(root.path, 'content'));
    final slotA = Directory(path.join(contentRoot.path, 'slot-a'));
    final pointer = File(path.join(contentRoot.path, 'active-pointer.json'));
    await slotA.create(recursive: true);

    final manifest =
        jsonDecode(
              await rootBundle.loadString('assets/content/demo_manifest.json'),
            )
            as Map<String, dynamic>;
    final bundledVersion = manifest['datasetVersion']! as int;
    var installedVersion = 0;
    if (await pointer.exists()) {
      final existing =
          jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
      installedVersion = existing['datasetVersion'] as int? ?? 0;
    }

    if (!await pointer.exists() || installedVersion < bundledVersion) {
      final target = File(path.join(slotA.path, 'reference.sqlite'));
      final data = await rootBundle.load(_bundledDatabaseAsset);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await _writePointer(
        pointer,
        slot: 'slot-a',
        datasetVersion: bundledVersion,
      );
    }

    final pointerData =
        jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
    final slot = pointerData['slot'] as String?;
    if (slot == null || !RegExp(r'^slot-[ab]$').hasMatch(slot)) {
      throw const FormatException('Active content pointer is invalid.');
    }
    final database = File(
      path.join(contentRoot.path, slot, 'reference.sqlite'),
    );
    if (!await database.exists()) {
      throw StateError('Active content database is missing.');
    }
    return database.path;
  }

  Future<void> _writePointer(
    File pointer, {
    required String slot,
    required int datasetVersion,
  }) async {
    final temporary = File('${pointer.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'slot': slot,
        'datasetVersion': datasetVersion,
        'activatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(pointer.path);
  }
}
