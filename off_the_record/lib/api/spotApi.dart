import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'package:off_the_record/storage/models.dart';

class SpotApi {
  static const _clientId = '34a4f733d57a499da800f3e6bf189b76';

  /// Same client ID used by the Web API PKCE login above, reused by
  /// [SpotifyPlayback] for the separate App Remote OAuth handshake.
  static const clientId = _clientId;
  static const _redirectUri = 'off-the-record://callback';
  static const _scopes = 'user-read-private user-read-email playlist-read-private '
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
      'client_id': _clientId,
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

    final code = Uri.parse(result).queryParameters['code']!;
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
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _storage.write(key: _accessKey, value: data['access_token'] as String);
    await _storage.write(key: _refreshKey, value: data['refresh_token'] as String);
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
        if (track == null || track['id'] == null) continue;
        final artists = (track['artists'] as List?)
            ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
            .join(', ');
        final images = (track['album'] as Map<String, dynamic>?)?['images'] as List?;
        tracks.add(LocalTrack(
          spotifyTrackId: track['id'] as String,
          title: track['name'] as String? ?? '',
          artist: artists ?? '',
          albumArtUrl: (images != null && images.isNotEmpty)
              ? images[0]['url'] as String?
              : null,
          durationMs: track['duration_ms'] as int?,
        ));
      }

      final nextUrl = data['next'] as String?;
      next = nextUrl != null ? Uri.parse(nextUrl) : null;
    }

    return tracks;
  }

  static Future<void> logout() => _storage.deleteAll();
}
