/// App-level authentication state, independent of token storage details.
sealed class AuthState {
  const AuthState();
}

/// Startup state before stored tokens have been checked.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// No usable session — show the login screen.
class SignedOut extends AuthState {
  const SignedOut();
}

/// A valid session exists for the given Bungie.net membership.
class SignedIn extends AuthState {
  const SignedIn(this.membershipId);

  final String membershipId;
}
