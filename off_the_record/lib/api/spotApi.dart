import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'package:off_the_record/config/env.dart';
import 'package:off_the_record/storage/models.dart';

class SpotApi {
  /// Injected at build time — see [Env] and OffTheRecord_HANDOFF.md §9.
  /// Also reused by `SpotifyPlayback` for the separate App Remote OAuth
  /// handshake.
  static String get clientId => Env.requireSpotifyClientId();

  static const _redirectUri = 'off-the-record://callback';

  /// `playlist-modify-private` covers creating collaborative playlists —
  /// Spotify only allows the collaborative flag on private playlists.
  static const _scopes = 'user-read-private user-read-email playlist-read-private '
      'playlist-read-collaborative playlist-modify-private playlist-modify-public '
      'user-top-read user-read-playback-state';

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'spot_access_token';
  static const _refreshKey = 'spot_refresh_token';

  static String _buildVerifier() {
    final rand = Random.secure();
    final bytes = Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _buildChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static Future<void> login() async {
    final verifier = _buildVerifier();
    final challenge = _buildChallenge(verifier);

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': _scopes,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'off-the-record',
    );

    final params = Uri.parse(result).queryParameters;
    // A denied consent screen redirects back with `error` and no `code`.
    final error = params['error'];
    if (error != null) throw StateError('Spotify authorization failed: $error');
    final code = params['code'];
    if (code == null) throw StateError('Spotify returned no authorization code');
    await _exchangeCode(code, verifier);
  }

  static Future<void> _exchangeCode(String code, String verifier) async {
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': clientId,
        'code_verifier': verifier,
      },
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    if (accessToken == null) {
      throw StateError(
        'Spotify token exchange failed: ${data['error_description'] ?? data['error'] ?? res.body}',
      );
    }
    await _storage.write(key: _accessKey, value: accessToken);
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  static Future<String?> _accessToken() => _storage.read(key: _accessKey);

  static Future<bool> isSignedIn() async => await _accessToken() != null;

  static Future<Map<String, dynamic>> getMe() async {
    final token = await _accessToken();
    final res = await http.get(
      Uri.parse('https://api.spotify.com/v1/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPlaylists() async {
    final token = await _accessToken();
    final res = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/playlists?limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  static Future<List<LocalTrack>> getPlaylistTracks(String playlistId) async {
    final token = await _accessToken();
    final tracks = <LocalTrack>[];
    Uri? next = Uri.parse(
      'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=100',
    );

    while (next != null) {
      final res = await http.get(next, headers: {'Authorization': 'Bearer $token'});
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      for (final item in (data['items'] as List)) {
        final track = (item as Map<String, dynamic>)['track'] as Map<String, dynamic>?;
        if (track == null) continue;
        final parsed = trackFromJson(track);
        if (parsed != null) tracks.add(parsed);
      }

      final nextUrl = data['next'] as String?;
      next = nextUrl != null ? Uri.parse(nextUrl) : null;
    }

    return tracks;
  }

  /// Parses one Spotify track object into local metadata. Returns null for
  /// entries the app can't play (local files, unavailable tracks).
  static LocalTrack? trackFromJson(Map<String, dynamic> track) {
    final id = track['id'] as String?;
    if (id == null) return null;
    final artists = (track['artists'] as List?)
        ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
        .join(', ');
    final images = (track['album'] as Map<String, dynamic>?)?['images'] as List?;
    return LocalTrack(
      spotifyTrackId: id,
      title: track['name'] as String? ?? '',
      artist: artists ?? '',
      albumArtUrl: (images != null && images.isNotEmpty) ? images[0]['url'] as String? : null,
      durationMs: track['duration_ms'] as int?,
    );
  }

  /// Track search for building custom playlists (handoff §5). Requires an
  /// authenticated user — local-save users have no search.
  static Future<List<LocalTrack>> searchTracks(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    final token = await _accessToken();
    final res = await http.get(
      Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '$limit',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['tracks'] as Map<String, dynamic>?)?['items'] as List?;
    if (items == null) return const [];
    return items
        .map((t) => trackFromJson(t as Map<String, dynamic>))
        .whereType<LocalTrack>()
        .toList();
  }

  /// Creates a playlist on the user's Spotify account and returns its ID.
  ///
  /// Spotify only honours the collaborative flag on **private** playlists, so
  /// a collaborative request is forced to `public: false` — see handoff §5.
  /// Collaborators then edit it in Spotify itself; the app just re-syncs.
  static Future<String> createPlaylist(
    String name, {
    bool collaborative = false,
    String description = 'Created in OffTheRecord',
  }) async {
    final token = await _accessToken();
    final me = await getMe();
    final userId = me['id'] as String?;
    if (userId == null) {
      throw StateError('Could not read your Spotify profile — sign in again');
    }

    final res = await http.post(
      Uri.parse('https://api.spotify.com/v1/users/$userId/playlists'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'public': collaborative ? false : true,
        'collaborative': collaborative,
      }),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id == null) {
      final error = data['error'];
      throw StateError(
        'Could not create the Spotify playlist: '
        '${error is Map ? error['message'] : res.body}',
      );
    }
    return id;
  }

  /// Adds tracks to a Spotify playlist, 100 at a time (the API's page limit).
  static Future<void> addTracksToPlaylist(
    String playlistId,
    List<String> trackIds,
  ) async {
    if (trackIds.isEmpty) return;
    final token = await _accessToken();

    for (var start = 0; start < trackIds.length; start += 100) {
      final chunk = trackIds.sublist(start, min(start + 100, trackIds.length));
      final res = await http.post(
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'uris': chunk.map((id) => 'spotify:track:$id').toList()}),
      );
      if (res.statusCode >= 400) {
        throw StateError('Could not add tracks to the Spotify playlist: ${res.body}');
      }
    }
  }

  /// Share link for a playlist, so collaborators can be invited from the app.
  static String playlistShareUrl(String playlistId) =>
      'https://open.spotify.com/playlist/$playlistId';

  static Future<void> logout() => _storage.deleteAll();
}
