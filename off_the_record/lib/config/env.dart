/// Build-time configuration (see OffTheRecord_HANDOFF.md §9).
///
/// Nothing secret lives in this file — values arrive via `--dart-define`, so
/// the checked-in source stays free of credentials. Supply them with a local
/// `dart_defines.json` (gitignored; copy `dart_defines.example.json`):
///
/// ```
/// flutter run --dart-define-from-file=dart_defines.json
/// ```
abstract class Env {
  /// Spotify application client ID, shared by the Web API PKCE login
  /// (`SpotApi`) and the App Remote handshake (`SpotifyPlayback`).
  static const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');

  static bool get hasSpotifyClientId => spotifyClientId.isNotEmpty;

  /// Throws a message that names the fix, rather than letting Spotify reject
  /// an empty `client_id` with an opaque HTTP error.
  static String requireSpotifyClientId() {
    if (!hasSpotifyClientId) {
      throw StateError(
        'SPOTIFY_CLIENT_ID is not set. Copy dart_defines.example.json to '
        'dart_defines.json, fill in your client ID, and run with '
        '--dart-define-from-file=dart_defines.json',
      );
    }
    return spotifyClientId;
  }
}
