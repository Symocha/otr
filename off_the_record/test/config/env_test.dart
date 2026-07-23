import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/config/env.dart';

void main() {
  group('Env', () {
    // Tests run without --dart-define, so this exercises the unset branch.
    // The point of the guard is that a missing define fails loudly at the call
    // site instead of reaching Spotify as an empty client_id.
    test('reports a missing client ID rather than defaulting', () {
      expect(Env.hasSpotifyClientId, isFalse);
      expect(Env.spotifyClientId, isEmpty);
    });

    test('requireSpotifyClientId throws a message naming the fix', () {
      expect(
        () => Env.requireSpotifyClientId(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SPOTIFY_CLIENT_ID'), contains('dart_defines.json')),
          ),
        ),
      );
    });
  });
}
