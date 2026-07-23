import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/game/game_session.dart';
import 'package:off_the_record/net/host_server.dart';
import 'package:off_the_record/storage/models.dart';

LocalPlaylist _playlistOf(int trackCount) => LocalPlaylist(
      id: 'p1',
      name: '$trackCount-track playlist',
      tracks: List.generate(
        trackCount,
        (i) => LocalTrack(spotifyTrackId: '$i', title: 'Song $i', artist: 'Artist $i'),
      ),
    );

void main() {
  group('GameSession round count', () {
    late HostServer server;
    GameSession? session;

    setUp(() => server = HostServer());
    tearDown(() => session?.dispose());

    test('caps the game at maxRounds when the playlist is longer', () {
      session = GameSession(server: server, playlist: _playlistOf(40), maxRounds: 10)..start();
      expect(session!.totalRounds, 10);
    });

    test('plays every track when the playlist is shorter than maxRounds', () {
      session = GameSession(server: server, playlist: _playlistOf(3), maxRounds: 10)..start();
      expect(session!.totalRounds, 3);
    });

    test('defaults to 10 rounds', () {
      session = GameSession(server: server, playlist: _playlistOf(40))..start();
      expect(session!.totalRounds, 10);
    });

    test('honours a non-default round count from lobby settings', () {
      session = GameSession(server: server, playlist: _playlistOf(40), maxRounds: 20)..start();
      expect(session!.totalRounds, 20);
    });

    test('the opening track comes from the playlist', () {
      final playlist = _playlistOf(40);
      session = GameSession(server: server, playlist: playlist, maxRounds: 10)..start();
      expect(
        playlist.tracks.map((t) => t.spotifyTrackId),
        contains(session!.currentTrack!.spotifyTrackId),
      );
    });

    test('an empty playlist yields no rounds', () {
      session = GameSession(server: server, playlist: _playlistOf(0), maxRounds: 10)..start();
      expect(session!.totalRounds, 0);
    });
  });
}
