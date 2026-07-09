import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/failures.dart';

/// Downloads and unpacks the Destiny manifest SQLite database.
///
/// Bungie serves the mobile world content as a ZIP containing a single SQLite
/// `.content` file. The unpacked DB is stored under the app documents dir named
/// after its version, so the presence of that file is itself the version check.
class ManifestDownloader {
  ManifestDownloader(this._dio, {Logger? logger})
      : _log = logger ?? Logger();

  final Dio _dio;
  final Logger _log;

  /// Local path where the DB for [version] lives (may not exist yet).
  Future<String> localPathFor(String version) async {
    final dir = await getApplicationSupportDirectory();
    final safe = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${dir.path}${Platform.pathSeparator}manifest_$safe.sqlite';
  }

  /// Download the zipped DB from [relativePath] (relative to bungie.net) and
  /// write the unpacked SQLite file to the path for [version]. Reports byte
  /// progress via [onProgress]. Returns the local file path.
  Future<String> download({
    required String version,
    required String relativePath,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = '${AppConfig.bungieBaseUrl}$relativePath';
    _log.i('Downloading manifest $version from $url');

    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'X-API-Key': AppConfig.bungieApiKey},
          // The manifest is tens of MB; the default receive timeout is too short.
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: onProgress,
      );
    } on DioException catch (e) {
      throw NetworkFailure('Failed to download the manifest.', cause: e);
    }

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const ApiFailure('Manifest download was empty.');
    }

    final sqliteBytes = _unzipSingleEntry(bytes);
    final path = await localPathFor(version);
    await File(path).writeAsBytes(sqliteBytes, flush: true);
    _log.i('Manifest written to $path (${sqliteBytes.length} bytes)');
    return path;
  }

  /// The manifest ZIP holds exactly one entry (the SQLite file). Extract it.
  List<int> _unzipSingleEntry(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final file = archive.files.firstWhere(
      (f) => f.isFile,
      orElse: () =>
          throw const ApiFailure('Manifest archive contained no file.'),
    );
    return file.content as List<int>;
  }
}
