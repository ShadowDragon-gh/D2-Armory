import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/errors/failures.dart';

/// Downloads and caches Clarity's community-insight database.
///
/// Clarity publishes a tiny `versions.json` next to the full descriptions file
/// on GitHub Pages; the big file is only re-downloaded when the version number
/// changes. The stored version lives in a sidecar text file next to the cached
/// JSON (the cache is overwritten in place rather than version-suffixed).
///
/// These are public static files — no Bungie API key or auth headers, so this
/// takes a plain [Dio], not one from `DioClient`.
class ClarityDownloader {
  ClarityDownloader(this._dio, {Logger? logger}) : _log = logger ?? Logger();

  static const versionsUrl =
      'https://database-clarity.github.io/Live-Clarity-Database/versions.json';
  static const descriptionsUrl =
      'https://database-clarity.github.io/Live-Clarity-Database/descriptions/dim.json';

  final Dio _dio;
  final Logger _log;

  /// Current published version of the descriptions database.
  Future<double?> fetchVersion() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(versionsUrl);
      return (response.data?['descriptions'] as num?)?.toDouble();
    } on DioException catch (e) {
      throw NetworkFailure('Failed to fetch the Clarity version.', cause: e);
    }
  }

  /// Local path of the cached descriptions JSON (may not exist yet).
  Future<String> localPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}clarity_descriptions.json';
  }

  /// The version the cached file was downloaded at, or null when unknown.
  Future<String?> readStoredVersion() async {
    final file = File(await _versionPath());
    if (!file.existsSync()) return null;
    final raw = (await file.readAsString()).trim();
    return raw.isEmpty ? null : raw;
  }

  Future<void> writeStoredVersion(String version) async {
    await File(await _versionPath()).writeAsString(version, flush: true);
  }

  /// Download the descriptions database to [localPath].
  Future<void> download() async {
    _log.i('Downloading Clarity descriptions from $descriptionsUrl');
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        descriptionsUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
    } on DioException catch (e) {
      throw NetworkFailure(
          'Failed to download the Clarity database.', cause: e);
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const ApiFailure('Clarity download was empty.');
    }
    final path = await localPath();
    await File(path).writeAsBytes(bytes, flush: true);
    _log.i('Clarity descriptions written to $path (${bytes.length} bytes)');
  }

  Future<String> _versionPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}clarity_version.txt';
  }
}
