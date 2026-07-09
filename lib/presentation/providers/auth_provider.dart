import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../data/local/token_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/auth_state.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    unauthenticatedDio: DioClient.unauthenticated(),
    storage: ref.watch(tokenStorageProvider),
  );
});

/// Drives sign-in / sign-out and exposes the current [AuthState]. On startup
/// [build] restores any persisted session.
class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    // A failure to read persisted tokens (e.g. secure storage unavailable)
    // must land on the login screen, not leave the app on a splash.
    try {
      return await _repo.hasValidSession()
          ? const SignedIn('')
          : const SignedOut();
    } catch (_) {
      return const SignedOut();
    }
  }

  /// Start the interactive Bungie sign-in. Surfaces failures as an
  /// [AsyncError] the UI can render; leaves state signed-out on failure.
  Future<void> signIn() async {
    state = const AsyncLoading();
    try {
      final tokens = await _repo.signIn();
      state = AsyncData(SignedIn(tokens.membershipId));
    } catch (e, st) {
      // Any error (not just Failure) must land in AsyncError, otherwise the
      // UI stays stuck on the loading state.
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(SignedOut());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
