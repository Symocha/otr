import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/api/spotApi.dart';

Map<String, dynamic> _track({
  Object? id = '4uLU6hMCjMI75M1A2tKUQC',
  List<Map<String, dynamic>>? artists,
  List<Map<String, dynamic>>? images,
  Object? durationMs = 213000,
}) =>
    {
      'id': id,
      'name': 'Never Gonna Give You Up',
      'duration_ms': durationMs,
      'artists': artists ?? [
        {'name': 'Rick Astley'},
      ],
      'album': {'images': images ?? [
        {'url': 'https://i.scdn.co/image/abc'},
      ]},
    };

void main() {
  group('SpotApi.trackFromJson', () {
    test('maps a full track object', () {
      final track = SpotApi.trackFromJson(_track())!;
      expect(track.spotifyTrackId, '4uLU6hMCjMI75M1A2tKUQC');
      expect(track.title, 'Never Gonna Give You Up');
      expect(track.artist, 'Rick Astley');
      expect(track.albumArtUrl, 'https://i.scdn.co/image/abc');
      expect(track.durationMs, 213000);
    });

    test('joins multiple artists', () {
      final track = SpotApi.trackFromJson(_track(artists: [
        {'name': 'Daft Punk'},
        {'name': 'Pharrell Williams'},
      ]))!;
      expect(track.artist, 'Daft Punk, Pharrell Williams');
    });

    test('returns null for an entry with no id', () {
      // Local files and unavailable tracks come back with a null id and are
      // unplayable through the App Remote.
      expect(SpotApi.trackFromJson(_track(id: null)), isNull);
    });

    test('tolerates a missing album image', () {
      final track = SpotApi.trackFromJson(_track(images: []))!;
      expect(track.albumArtUrl, isNull);
    });

    test('tolerates a missing duration', () {
      final track = SpotApi.trackFromJson(_track(durationMs: null))!;
      expect(track.durationMs, isNull);
    });
  });

  group('SpotApi.playlistShareUrl', () {
    test('builds an open.spotify.com link', () {
      expect(
        SpotApi.playlistShareUrl('37i9dQZF1DXcBWIGoYBM5M'),
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
      );
    });
  });
}
