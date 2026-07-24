import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/data/homelab_app_update_service.dart';
import 'package:pokemon_adventure/domain/repositories.dart';

void main() {
  late Directory temporaryDirectory;
  late HttpServer server;
  late _PlatformFake platform;
  late List<int> apkBytes;
  late Map<String, Object?> manifest;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'pokemon-update-test-',
    );
    apkBytes = utf8.encode('verified test apk');
    platform = _PlatformFake(
      appInfo: InstalledAppInfo(
        packageName: HomelabAppUpdateService.packageName,
        versionCode: 1,
        versionName: '1.0.0',
      ),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    manifest = {
      'schemaVersion': 1,
      'packageName': HomelabAppUpdateService.packageName,
      'versionCode': 2,
      'versionName': '1.1.0',
      'apkUrl': '/pokemon-adventure.apk',
      'sha256': sha256.convert(apkBytes).toString(),
      'sizeBytes': apkBytes.length,
      'title': 'More Pokémon fun',
      'notes': ['A friendlier update screen', 'New discoveries'],
    };
    server.listen((request) async {
      if (request.uri.path == '/latest.json') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(manifest));
      } else if (request.uri.path == '/pokemon-adventure.apk') {
        request.response.headers.contentType = ContentType(
          'application',
          'vnd.android.package-archive',
        );
        final range = request.headers.value(HttpHeaders.rangeHeader);
        final match = range == null
            ? null
            : RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
        if (match == null) {
          request.response.contentLength = apkBytes.length;
          request.response.add(apkBytes);
        } else {
          final start = int.parse(match.group(1)!);
          final requestedEnd = int.parse(match.group(2)!);
          final end = requestedEnd < apkBytes.length
              ? requestedEnd
              : apkBytes.length - 1;
          final bytes = apkBytes.sublist(start, end + 1);
          request.response
            ..statusCode = HttpStatus.partialContent
            ..contentLength = bytes.length
            ..headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-$end/${apkBytes.length}',
            )
            ..add(bytes);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await temporaryDirectory.delete(recursive: true);
  });

  HomelabAppUpdateService makeService(AppUpdatePlatform updatePlatform) {
    return HomelabAppUpdateService(
      manifestUrl:
          'http://${server.address.address}:${server.port}/latest.json',
      platform: updatePlatform,
      supportDirectory: () async => temporaryDirectory,
      downloadChunkBytes: 5,
    );
  }

  test('discovers a newer homelab APK release', () async {
    final service = makeService(platform);

    final result = await service.check(currentDatasetVersion: 4);

    expect(result.state, UpdateCheckState.updateAvailable);
    expect(result.release?.versionCode, 2);
    expect(result.release?.versionName, '1.1.0');
    expect(result.release?.notes, hasLength(2));
  });

  test('reports current when homelab version code is not newer', () async {
    manifest['versionCode'] = 1;
    final service = makeService(platform);

    final result = await service.check(currentDatasetVersion: 4);

    expect(result.state, UpdateCheckState.current);
    expect(result.release, isNull);
  });

  test('rejects a manifest that redirects the APK to another server', () async {
    manifest['apkUrl'] = 'http://example.com/pokemon-adventure.apk';
    final service = makeService(platform);

    final result = await service.check(currentDatasetVersion: 4);

    expect(result.state, UpdateCheckState.failed);
    expect(result.release, isNull);
  });

  test('downloads, verifies, and hands APK to Android installer', () async {
    final mutablePlatform = _PlatformFake(
      appInfo: platform.appInfo,
      installAllowed: true,
    );
    final service = makeService(mutablePlatform);
    final check = await service.check(currentDatasetVersion: 4);
    final progress = <double>[];

    final apkPath = await service.download(
      check.release!,
      onProgress: progress.add,
    );
    final request = await service.requestInstall(apkPath);

    expect(await File(apkPath).readAsBytes(), apkBytes);
    expect(progress.last, 1);
    expect(request, UpdateInstallRequest.launched);
    expect(mutablePlatform.launchedApkPath, apkPath);
  });

  test('rejects an APK whose checksum does not match', () async {
    manifest['sha256'] = '0' * 64;
    final service = makeService(platform);
    final check = await service.check(currentDatasetVersion: 4);

    await expectLater(
      service.download(check.release!, onProgress: (_) {}),
      throwsA(isA<FormatException>()),
    );

    final updateDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}updates',
    );
    expect(
      updateDirectory.existsSync()
          ? updateDirectory.listSync().whereType<File>()
          : const <File>[],
      isEmpty,
    );
  });

  test('opens Android install-source permission before installation', () async {
    final service = makeService(platform);

    final result = await service.requestInstall('verified-update.apk');

    expect(result, UpdateInstallRequest.permissionNeeded);
    expect(platform.permissionOpened, isTrue);
    expect(platform.launchedApkPath, isNull);
  });
}

class _PlatformFake implements AppUpdatePlatform {
  _PlatformFake({required this.appInfo, this.installAllowed = false});

  final InstalledAppInfo appInfo;
  final bool installAllowed;
  String? launchedApkPath;
  bool permissionOpened = false;

  @override
  Future<bool> canRequestInstall() async => installAllowed;

  @override
  Future<InstalledAppInfo> getInstalledAppInfo() async => appInfo;

  @override
  Future<void> launchInstaller(String apkPath) async {
    launchedApkPath = apkPath;
  }

  @override
  Future<void> openInstallPermission() async {
    permissionOpened = true;
  }
}
