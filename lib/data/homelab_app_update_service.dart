import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../domain/repositories.dart';

class InstalledAppInfo {
  const InstalledAppInfo({
    required this.packageName,
    required this.versionCode,
    required this.versionName,
  });

  final String packageName;
  final int versionCode;
  final String versionName;
}

abstract interface class AppUpdatePlatform {
  Future<InstalledAppInfo> getInstalledAppInfo();

  Future<bool> canRequestInstall();

  Future<void> openInstallPermission();

  Future<void> launchInstaller(String apkPath);
}

class AndroidAppUpdatePlatform implements AppUpdatePlatform {
  static const _channel = MethodChannel(
    'com.chavezfamily.pokemon_adventure/app_updates',
  );

  @override
  Future<InstalledAppInfo> getInstalledAppInfo() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getInstalledAppInfo',
    );
    if (result == null) {
      throw StateError('Android did not return installed app information.');
    }
    return InstalledAppInfo(
      packageName: result['packageName']! as String,
      versionCode: (result['versionCode']! as num).toInt(),
      versionName: result['versionName']! as String,
    );
  }

  @override
  Future<bool> canRequestInstall() async {
    return await _channel.invokeMethod<bool>('canRequestInstall') ?? false;
  }

  @override
  Future<void> openInstallPermission() =>
      _channel.invokeMethod<void>('openInstallPermission');

  @override
  Future<void> launchInstaller(String apkPath) =>
      _channel.invokeMethod<void>('launchInstaller', {'apkPath': apkPath});
}

class HomelabAppUpdateService implements AppUpdateService {
  HomelabAppUpdateService({
    this._manifestUrl = const String.fromEnvironment('APP_UPDATE_MANIFEST_URL'),
    AppUpdatePlatform? platform,
    HttpClient Function()? httpClientFactory,
    Future<Directory> Function()? supportDirectory,
  }) : _platform = platform ?? AndroidAppUpdatePlatform(),
       _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const packageName = 'com.chavezfamily.pokemon_adventure';
  static const _maximumManifestBytes = 128 * 1024;
  static const _maximumApkBytes = 750 * 1024 * 1024;

  final String _manifestUrl;
  final AppUpdatePlatform _platform;
  final HttpClient Function() _httpClientFactory;
  final Future<Directory> Function() _supportDirectory;

  @override
  Future<UpdateCheckResult> check({required int currentDatasetVersion}) async {
    if (_manifestUrl.trim().isEmpty) {
      return const UpdateCheckResult(
        state: UpdateCheckState.disabled,
        message: 'Family updates are not connected yet.',
      );
    }

    try {
      final manifestUri = Uri.parse(_manifestUrl);
      _requireSecureUri(manifestUri, label: 'manifest');
      final installed = await _platform.getInstalledAppInfo();
      if (installed.packageName != packageName) {
        throw const FormatException('Installed package name does not match.');
      }
      final manifest = await _readManifest(manifestUri);
      final release = _parseRelease(manifest, manifestUri);
      if (release.versionCode <= installed.versionCode) {
        return UpdateCheckResult(
          state: UpdateCheckState.current,
          message: 'App version ${installed.versionName} is ready to explore.',
        );
      }
      return UpdateCheckResult(
        state: UpdateCheckState.updateAvailable,
        message: 'A new adventure is ready!',
        release: release,
      );
    } on Object {
      return const UpdateCheckResult(
        state: UpdateCheckState.failed,
        message: 'Could not check for updates. The app still works offline.',
      );
    }
  }

  @override
  Future<String> download(
    AppUpdateRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    _requireSecureUri(release.apkUri, label: 'APK');
    if (release.sizeBytes <= 0 || release.sizeBytes > _maximumApkBytes) {
      throw const FormatException('APK size is outside the allowed range.');
    }

    final root = await _supportDirectory();
    final updates = Directory(path.join(root.path, 'updates'));
    await updates.create(recursive: true);
    final finalFile = File(
      path.join(updates.path, 'pokemon-adventure-${release.versionCode}.apk'),
    );
    final partialFile = File('${finalFile.path}.part');
    if (await partialFile.exists()) {
      await partialFile.delete();
    }

    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? output;
    try {
      final request = await client.getUrl(release.apkUri);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      _validateResponse(response, release.apkUri);
      if (response.contentLength > 0 &&
          response.contentLength != release.sizeBytes) {
        throw const FormatException(
          'APK size does not match the release manifest.',
        );
      }

      output = partialFile.openWrite();
      final digestOutput = AccumulatorSink<Digest>();
      final digestInput = sha256.startChunkedConversion(digestOutput);
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > release.sizeBytes || received > _maximumApkBytes) {
          throw const FormatException('APK download is larger than expected.');
        }
        output.add(chunk);
        digestInput.add(chunk);
        onProgress(received / release.sizeBytes);
      }
      await output.flush();
      await output.close();
      output = null;
      digestInput.close();

      if (received != release.sizeBytes) {
        throw const FormatException(
          'APK download ended before it was complete.',
        );
      }
      final actualHash = digestOutput.events.single.toString().toLowerCase();
      if (actualHash != release.sha256) {
        throw const FormatException('APK checksum verification failed.');
      }
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await partialFile.rename(finalFile.path);
      onProgress(1);
      return finalFile.path;
    } finally {
      await output?.close();
      client.close(force: true);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
    }
  }

  @override
  Future<UpdateInstallRequest> requestInstall(String apkPath) async {
    if (!await _platform.canRequestInstall()) {
      await _platform.openInstallPermission();
      return UpdateInstallRequest.permissionNeeded;
    }
    await _platform.launchInstaller(apkPath);
    return UpdateInstallRequest.launched;
  }

  Future<Map<String, Object?>> _readManifest(Uri uri) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      _validateResponse(response, uri);
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumManifestBytes) {
          throw const FormatException('Update manifest is too large.');
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Update manifest must be an object.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  AppUpdateRelease _parseRelease(
    Map<String, Object?> manifest,
    Uri manifestUri,
  ) {
    if (manifest['schemaVersion'] != 1 ||
        manifest['packageName'] != packageName) {
      throw const FormatException('Unsupported update manifest.');
    }
    final versionCode = _positiveInt(manifest, 'versionCode');
    final versionName = _requiredString(manifest, 'versionName', maxLength: 40);
    final apkValue = _requiredString(manifest, 'apkUrl', maxLength: 2048);
    final apkUri = manifestUri.resolve(apkValue);
    _requireSecureUri(apkUri, label: 'APK');
    if (apkUri.origin != manifestUri.origin) {
      throw const FormatException(
        'APK URL must use the same server as the manifest.',
      );
    }
    final checksum = _requiredString(
      manifest,
      'sha256',
      maxLength: 64,
    ).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
      throw const FormatException('APK checksum must be SHA-256.');
    }
    final sizeBytes = _positiveInt(manifest, 'sizeBytes');
    if (sizeBytes > _maximumApkBytes) {
      throw const FormatException('APK is larger than the supported limit.');
    }
    final title = _requiredString(manifest, 'title', maxLength: 80);
    final rawNotes = manifest['notes'];
    if (rawNotes is! List ||
        rawNotes.length > 6 ||
        rawNotes.any((note) => note is! String || note.length > 160)) {
      throw const FormatException('Release notes are invalid.');
    }
    return AppUpdateRelease(
      versionCode: versionCode,
      versionName: versionName,
      apkUri: apkUri,
      sha256: checksum,
      sizeBytes: sizeBytes,
      title: title,
      notes: List.unmodifiable(rawNotes.cast<String>()),
    );
  }

  void _validateResponse(HttpClientResponse response, Uri requestedUri) {
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Update server returned HTTP ${response.statusCode}.',
        uri: requestedUri,
      );
    }
    if (!kDebugMode &&
        response.redirects.any(
          (redirect) => redirect.location.scheme.toLowerCase() != 'https',
        )) {
      throw const FormatException('Update server redirected away from HTTPS.');
    }
  }

  void _requireSecureUri(Uri uri, {required String label}) {
    final scheme = uri.scheme.toLowerCase();
    if (!uri.hasAuthority ||
        (scheme != 'https' && !(kDebugMode && scheme == 'http'))) {
      throw FormatException('$label URL must use HTTPS.');
    }
  }

  int _positiveInt(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! num || value.toInt() != value || value <= 0) {
      throw FormatException('$key must be a positive integer.');
    }
    return value.toInt();
  }

  String _requiredString(
    Map<String, Object?> source,
    String key, {
    required int maxLength,
  }) {
    final value = source[key];
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }
}
