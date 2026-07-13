import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/failures.dart';
import '../../core/update/update_installer.dart';
import '../../domain/models/app_release.dart';
import '../../domain/models/app_version.dart';
import '../../data/repositories/update_repository.dart';

/// Plain Dio for GitHub — a different host than Bungie, so it must not carry
/// the Bungie API-key/Bearer interceptors from [DioClient].
final _githubDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    followRedirects: true,
  ));
});

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  return UpdateRepository(ref.watch(_githubDioProvider));
});

final updateInstallerProvider =
    Provider<UpdateInstaller>((ref) => UpdateInstaller());

/// The running app's version, parsed from the bundled package metadata.
final currentVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
});

/// Progress of an in-flight update download, 0.0–1.0, or null when idle.
class UpdateDownloadProgress extends Notifier<double?> {
  @override
  double? build() => null;

  void set(double? value) => state = value;
}

final updateDownloadProgressProvider =
    NotifierProvider<UpdateDownloadProgress, double?>(
        UpdateDownloadProgress.new);

/// One-shot check for a newer release. Null means "up to date / unavailable".
/// Only runs on Windows (the only platform that can self-update).
final availableUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  if (!UpdateInstaller.isSupported) return null;
  final current = await ref.watch(currentVersionProvider.future);
  return ref.watch(updateRepositoryProvider).checkForUpdate(current);
});

/// Drives the download → verify → install → relaunch sequence for a release.
class UpdateController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Download and verify [release], then hand off to the installer and exit so
  /// the helper can swap files. On any failure the app stays running and the
  /// error surfaces via [state] — the install is never left half-applied.
  Future<void> downloadAndInstall(AppRelease release) async {
    state = const AsyncLoading();
    final progress = ref.read(updateDownloadProgressProvider.notifier);
    try {
      final zipPath = await ref.read(updateRepositoryProvider).downloadZip(
        release,
        onProgress: (received, total) {
          progress.set(total > 0 ? received / total : null);
        },
      );
      progress.set(null);
      await ref.read(updateInstallerProvider).installAndRelaunch(zipPath);
      // The helper waits for this process to exit before swapping files.
      state = const AsyncData(null);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      exit(0);
    } on Failure catch (e, st) {
      progress.set(null);
      state = AsyncError(e, st);
    } catch (e, st) {
      progress.set(null);
      state = AsyncError(
        UpdateFailure('Update failed unexpectedly.', cause: e),
        st,
      );
    }
  }
}

final updateControllerProvider =
    AsyncNotifierProvider<UpdateController, void>(UpdateController.new);
