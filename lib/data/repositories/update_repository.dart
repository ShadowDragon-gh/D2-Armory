import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/failures.dart';
import '../../domain/models/app_release.dart';
import '../../domain/models/app_version.dart';

/// Checks GitHub Releases for a newer build and downloads its zip.
///
/// The check is unauthenticated, so it only works once the repository is
/// public. While the repo is private GitHub answers 404, which is reported as
/// "no update available" (null) rather than an error — the updater stays quiet
/// until publishing is possible.
class UpdateRepository {
  UpdateRepository(this._dio, {Logger? logger}) : _log = logger ?? Logger();

  final Dio _dio;
  final Logger _log;

  /// Returns the latest release if it is strictly newer than [current];
  /// otherwise null (already up to date, repo private/unreachable, or the
  /// release has no usable zip asset).
  Future<AppRelease?> checkForUpdate(AppVersion current) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        AppConfig.latestReleaseUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          // Don't throw on 404 (private repo / no releases yet) — handle below.
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } on DioException catch (e) {
      // A transient network problem should not crash startup; treat the check
      // as inconclusive and try again next launch.
      _log.w('Update check failed (network): ${e.message}');
      return null;
    }

    if (response.statusCode != 200) {
      _log.i('Update check: no release available (HTTP ${response.statusCode}).');
      return null;
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    final release = AppRelease.tryParse(data);
    if (release == null) {
      _log.i('Update check: latest release has no usable version/zip asset.');
      return null;
    }

    if (release.version > current) {
      _log.i('Update available: ${release.version} (current $current).');
      return release;
    }
    _log.i('Update check: already up to date ($current).');
    return null;
  }

  /// Download [release]'s zip to a temp file, verifying byte count and — when
  /// the release published one — its SHA-256. Returns the downloaded path.
  /// Throws [UpdateFailure] on any transport or integrity problem so a
  /// corrupt/interrupted download can never reach the file-swap step.
  Future<String> downloadZip(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}d2armory_update_${release.tag}.zip';

    try {
      await _dio.download(
        release.zipUrl,
        path,
        onReceiveProgress: onProgress,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
    } on DioException catch (e) {
      throw UpdateFailure('Failed to download the update.', cause: e);
    }

    final file = File(path);
    final bytes = await file.readAsBytes();

    if (release.zipSize > 0 && bytes.length != release.zipSize) {
      await _deleteQuietly(file);
      throw UpdateFailure(
        'Update download was incomplete '
        '(${bytes.length} of ${release.zipSize} bytes).',
      );
    }

    if (release.sha256 != null) {
      final actual = sha256.convert(bytes).toString();
      if (actual != release.sha256) {
        await _deleteQuietly(file);
        throw UpdateFailure(
          'Update checksum did not match; the download may be corrupt.',
        );
      }
    } else {
      _log.w('Release ${release.tag} published no sha256; skipping hash check.');
    }

    _log.i('Update ${release.tag} downloaded and verified: $path');
    return path;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup; a leftover temp file is harmless.
    }
  }
}
