import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/storage/models.dart';

void main() {
  group('LocalTrack round-trip', () {
    test('with all fields', () {
      const track = LocalTrack(
        spotifyTrackId: '003vvx7Niy0yvhvHt4a68B',
        title: 'Mr. Brightside',
        artist: 'The Killers',
        albumArtUrl: 'https://example.com/art.jpg',
        durationMs: 222973,
      );
      final decoded = LocalTrack.fromJson(track.toJson());
      expect(decoded.spotifyTrackId, track.spotifyTrackId);
      expect(decoded.title, track.title);
      expect(decoded.artist, track.artist);
      expect(decoded.albumArtUrl, track.albumArtUrl);
      expect(decoded.durationMs, track.durationMs);
    });

    test('with nullable fields omitted', () {
      const track = LocalTrack(
        spotifyTrackId: '7tFiyTwD0nx5a1eklYtX2J',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
      );
      final decoded = LocalTrack.fromJson(track.toJson());
      expect(decoded.albumArtUrl, isNull);
      expect(decoded.durationMs, isNull);
    });
  });

  group('LocalPlaylist round-trip', () {
    test('premade playlist', () {
      const playlist = LocalPlaylist(
        id: 'abc123',
        name: 'Rock Classics',
        isPremade: true,
        tracks: [
          LocalTrack(spotifyTrackId: '1', title: 'Song A', artist: 'Artist A'),
          LocalTrack(spotifyTrackId: '2', title: 'Song B', artist: 'Artist B'),
        ],
      );
      final decoded = LocalPlaylist.fromJson(playlist.toJson());
      expect(decoded.id, 'abc123');
      expect(decoded.name, 'Rock Classics');
      expect(decoded.isPremade, isTrue);
      expect(decoded.spotifyPlaylistId, isNull);
      expect(decoded.tracks.length, 2);
      expect(decoded.tracks[0].title, 'Song A');
    });

    test('imported playlist retains spotifyPlaylistId', () {
      const playlist = LocalPlaylist(
        id: 'def456',
        name: 'My Playlist',
        spotifyPlaylistId: '37i9dQZF1DXcBWIGoYBM5M',
      );
      final decoded = LocalPlaylist.fromJson(playlist.toJson());
      expect(decoded.spotifyPlaylistId, '37i9dQZF1DXcBWIGoYBM5M');
      expect(decoded.isPremade, isFalse);
      expect(decoded.tracks, isEmpty);
    });

    test('copyWith replaces only given fields', () {
      const playlist = LocalPlaylist(id: 'ghi789', name: 'Original');
      final renamed = playlist.copyWith(name: 'Renamed');
      expect(renamed.id, 'ghi789');
      expect(renamed.name, 'Renamed');
    });
  });
}
