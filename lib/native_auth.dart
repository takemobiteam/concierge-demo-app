// Demo value for the code the shell sends in AUTH_CODE, set with
// `--dart-define=DEMO_AUTH_CODE=...` (or the .env*.json files). A concierge
// deployment running with MOCK_AUTH=true accepts a mock user id such as
// `usr-002` as the code, and its mock exchanges aren't single-use, so one
// fixed value works for every request.
//
// Real deployments need a fresh single-use code from the identity provider
// for every AUTH_REQUEST. This demo can't mint those; plug a real
// AuthCodeSource into NativeAuth instead.
const String kDemoAuthCode = String.fromEnvironment(
  'DEMO_AUTH_CODE',
  defaultValue: 'usr-002',
);

/// Supplies the code the shell sends to the concierge page in `AUTH_CODE`.
///
/// A real implementation asks the identity provider for a new single-use
/// code on every call. It must never return a code it has returned before,
/// since the page exchanges each code exactly once.
abstract interface class AuthCodeSource {
  Future<String> nextCode();
}

/// Returns the same configured value every time. Only suitable for a
/// MOCK_AUTH concierge deployment (or the bundled local demo page), where
/// codes are mock user ids and exchanges aren't single-use.
class DemoAuthCodeSource implements AuthCodeSource {
  final String code;

  const DemoAuthCodeSource([this.code = kDemoAuthCode]);

  @override
  Future<String> nextCode() async => code;
}

/// The shell's own signed-in state, which decides whether the concierge page
/// may be signed in at all. Stands in for a real native session.
class NativeAuth {
  final AuthCodeSource codeSource;
  bool _isSignedIn;

  NativeAuth({
    this.codeSource = const DemoAuthCodeSource(),
    bool isSignedIn = true,
  }) : _isSignedIn = isSignedIn;

  bool get isSignedIn => _isSignedIn;

  void signIn() => _isSignedIn = true;

  void signOut() => _isSignedIn = false;

  /// Mints a code for one `AUTH_REQUEST`, or returns null while signed out.
  Future<String?> codeForAuthRequest() async {
    if (!_isSignedIn) return null;
    final code = await codeSource.nextCode();
    // A real provider may be slow; don't hand out a code for a user who
    // signed out while it was being minted.
    return _isSignedIn ? code : null;
  }
}
