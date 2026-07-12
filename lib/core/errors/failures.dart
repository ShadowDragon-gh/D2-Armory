/// Typed failures surfaced by repositories and use cases.
///
/// Presentation code switches on the concrete type to decide how to react
/// (e.g. show a message, prompt re-auth). A [message] is always safe to show.
sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Network transport problem (no connection, timeout, DNS, etc.).
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// Bungie API returned an error status or an error envelope.
class ApiFailure extends Failure {
  const ApiFailure(super.message, {this.statusCode, this.errorCode, super.cause});

  /// HTTP status, if the response reached us.
  final int? statusCode;

  /// Bungie's `ErrorCode` from the platform response envelope, if present.
  final int? errorCode;
}

/// OAuth flow failed (user cancelled, state mismatch, token exchange error).
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

/// A cross-character move whose first hop (source → vault) succeeded but whose
/// second hop (vault → destination) failed: the item is now in the vault, not
/// where it was dragged. A distinct type so the UI can both message this and
/// patch the item to the vault, rather than reporting a false success.
class StrandedInVaultFailure extends Failure {
  const StrandedInVaultFailure(super.message, {super.cause});
}
