import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'package:off_the_record/api/spotApi.dart';

const _appRemoteRedirectUrl = 'spotify-sdk://auth';

/// Host-only wrapper around the Spotify App Remote SDK (see
/// OffTheRecord_HANDOFF.md §7). Every call is try/catch-wrapped the same
/// way: the package exposes no explicit "you got disconnected" stream, so a
/// thrown exception from any call *is* the disconnect signal callers react to.
class SpotifyPlayback extends ChangeNotifier {
  bool isConnected = false;
  String? connectionError;

  Future<bool> connect() async {
    try {
      await SpotifySdk.connectToSpotifyRemote(
        clientId: SpotApi.clientId,
        redirectUrl: _appRemoteRedirectUrl,
      );
      isConnected = true;
      connectionError = null;
      notifyListeners();
      return true;
    } catch (e) {
      isConnected = false;
      connectionError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> play(String spotifyTrackId, {int? seekToMs}) async {
    try {
      await SpotifySdk.play(spotifyUri: 'spotify:track:$spotifyTrackId');
      if (seekToMs != null) {
        await SpotifySdk.seekTo(positionedMilliseconds: seekToMs);
      }
      isConnected = true;
      connectionError = null;
      notifyListeners();
      return true;
    } catch (e) {
      isConnected = false;
      connectionError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      await SpotifySdk.pause();
      return true;
    } catch (e) {
      isConnected = false;
      connectionError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
    } catch (_) {
      // best-effort — nothing to react to on the way out
    }
    isConnected = false;
  }
}
