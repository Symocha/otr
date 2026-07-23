import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/game/game_session.dart';
import 'package:off_the_record/net/host_server.dart';
import 'package:off_the_record/storage/models.dart';

const _playlist = LocalPlaylist(
  id: 'p1',
  name: 'Test Playlist',
  tracks: [
    LocalTrack(spotifyTrackId: '1', title: 'Song One', artist: 'Artist One'),
    LocalTrack(spotifyTrackId: '2', title: 'Song Two', artist: 'Artist Two'),
  ],
);

void main() {
  group('GameSession pause/resume', () {
    late HostServer server;
    late GameSession session;

    setUp(() {
      // HostServer() alone never binds a socket (start() does that), so
      // broadcast()/sendTo() are safe in-memory no-ops here with zero
      // connected players — exactly what these pure timing tests need.
      server = HostServer();
      session = GameSession(server: server, playlist: _playlist, roundDurationMs: 30000, revealDurationMs: 1000);
      session.start();
    });

    tearDown(() {
      session.dispose();
    });

    test('remainingMs starts near the full round duration', () {
      expect(session.remainingMs, greaterThan(29000));
      expect(session.remainingMs, lessThanOrEqualTo(30000));
    });

    test('pause freezes remainingMs', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      session.pause();
      final frozen = session.remainingMs;
      expect(session.isPaused, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(session.remainingMs, frozen);
    });

    test('resume continues counting down from the frozen value', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      session.pause();
      final frozen = session.remainingMs;

      session.resume();
      expect(session.isPaused, isFalse);
      expect(session.remainingMs, closeTo(frozen.toDouble(), 20));
    });

    test('pause is idempotent', () {
      session.pause();
      session.pause();
      expect(session.isPaused, isTrue);
    });

    test('resume without a prior pause is a no-op', () {
      final before = session.remainingMs;
      session.resume();
      expect(session.isPaused, isFalse);
      expect(session.remainingMs, closeTo(before.toDouble(), 20));
    });
  });
}
