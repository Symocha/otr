import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:off_the_record/api/spotApi.dart';
import 'models.dart';

/// Bundled premade playlist assets, imported into the local box on first
/// launch (see OffTheRecord_HANDOFF.md §5).
const _premadeAssetPaths = [
  'assets/premade/2000s_hits.json',
  'assets/premade/rock_classics.json',
  'assets/premade/80s_icons.json',
];

String _generateId() {
  final rand = Random.secure();
  final bytes = List.generate(8, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// App-wide playlist repository instance, initialized once in `main()`.
final playlistRepository = PlaylistRepository();

/// Local playlist storage. Stores only track/playlist IDs and display
/// metadata — never audio. Backed by a Hive `Box<String>` of JSON blobs.
class PlaylistRepository extends ChangeNotifier {
  static const _boxName = 'playlists';
  late Box<String> _box;

  List<LocalPlaylist> get playlists => _box.values
      .map((raw) => LocalPlaylist.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList(growable: false);

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    if (_box.isEmpty) {
      await _importPremades();
    }
  }

  Future<void> _importPremades() async {
    for (final path in _premadeAssetPaths) {
      final raw = await rootBundle.loadString(path);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final playlist = LocalPlaylist(
        id: _generateId(),
        name: json['name'] as String,
        isPremade: true,
        tracks: (json['tracks'] as List)
            .map((t) => LocalTrack.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
      await _save(playlist);
    }
    notifyListeners();
  }

  Future<void> _save(LocalPlaylist playlist) =>
      _box.put(playlist.id, jsonEncode(playlist.toJson()));

  LocalPlaylist _get(String id) {
    final raw = _box.get(id);
    if (raw == null) throw StateError('No playlist with id $id');
    return LocalPlaylist.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void _requireEditable(LocalPlaylist playlist) {
    if (playlist.isPremade) {
      throw StateError('Premade playlists are read-only — duplicate them to edit');
    }
  }

  /// Local-save users' path to an editable playlist: copy a premade or
  /// imported playlist, then reorder/remove tracks from the copy.
  Future<LocalPlaylist> duplicate(String sourceId, {required String newName}) async {
    final source = _get(sourceId);
    final copy = LocalPlaylist(
      id: _generateId(),
      name: newName,
      isPremade: false,
      tracks: List.of(source.tracks),
    );
    await _save(copy);
    notifyListeners();
    return copy;
  }

  Future<void> rename(String id, String newName) async {
    final playlist = _get(id);
    _requireEditable(playlist);
    await _save(playlist.copyWith(name: newName));
    notifyListeners();
  }

  Future<void> reorderTracks(String id, int oldIndex, int newIndex) async {
    final playlist = _get(id);
    _requireEditable(playlist);
    final tracks = List.of(playlist.tracks);
    final track = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, track);
    await _save(playlist.copyWith(tracks: tracks));
    notifyListeners();
  }

  Future<void> removeTrack(String id, String spotifyTrackId) async {
    final playlist = _get(id);
    _requireEditable(playlist);
    final tracks = playlist.tracks.where((t) => t.spotifyTrackId != spotifyTrackId).toList();
    await _save(playlist.copyWith(tracks: tracks));
    notifyListeners();
  }

  /// Appends a track found via Spotify search (handoff §5). Duplicates are
  /// ignored so a double-tap in the search sheet can't corrupt the round list.
  Future<bool> addTrack(String id, LocalTrack track) async {
    final playlist = _get(id);
    _requireEditable(playlist);
    if (playlist.tracks.any((t) => t.spotifyTrackId == track.spotifyTrackId)) {
      return false;
    }
    await _save(playlist.copyWith(tracks: [...playlist.tracks, track]));
    notifyListeners();
    return true;
  }

  /// Creates an empty local playlist for a user to fill via search.
  Future<LocalPlaylist> create(String name) async {
    final playlist = LocalPlaylist(id: _generateId(), name: name);
    await _save(playlist);
    notifyListeners();
    return playlist;
  }

  /// Pushes a local playlist up to Spotify as a **collaborative** playlist and
  /// links the local copy to it (handoff §5).
  ///
  /// Collaboration itself is entirely Spotify's — friends edit the playlist in
  /// their own Spotify app, and [resync] pulls their changes back down. The app
  /// deliberately implements no custom collab sync.
  Future<LocalPlaylist> publishAsCollaborative(String id) async {
    final playlist = _get(id);
    // Premades stay read-only: linking one would let a resync overwrite the
    // bundled list.
    _requireEditable(playlist);
    if (playlist.spotifyPlaylistId != null) {
      throw StateError('This playlist is already linked to Spotify');
    }

    final spotifyId = await SpotApi.createPlaylist(playlist.name, collaborative: true);
    await SpotApi.addTracksToPlaylist(
      spotifyId,
      playlist.tracks.map((t) => t.spotifyTrackId).toList(),
    );

    final linked = playlist.copyWith(spotifyPlaylistId: spotifyId);
    await _save(linked);
    notifyListeners();
    return linked;
  }

  Future<void> delete(String id) async {
    final playlist = _get(id);
    _requireEditable(playlist);
    await _box.delete(id);
    notifyListeners();
  }

  /// Imports one of the signed-in user's real Spotify playlists as a local,
  /// re-syncable snapshot (track/ID metadata only).
  Future<LocalPlaylist> importFromSpotify(String spotifyPlaylistId, {required String name}) async {
    final tracks = await SpotApi.getPlaylistTracks(spotifyPlaylistId);
    final playlist = LocalPlaylist(
      id: _generateId(),
      name: name,
      spotifyPlaylistId: spotifyPlaylistId,
      isPremade: false,
      tracks: tracks,
    );
    await _save(playlist);
    notifyListeners();
    return playlist;
  }

  /// Pull-to-refresh: re-fetches tracks for a previously-imported playlist.
  Future<void> resync(String id) async {
    final playlist = _get(id);
    final spotifyId = playlist.spotifyPlaylistId;
    if (spotifyId == null) {
      throw StateError('Playlist $id was not imported from Spotify');
    }
    final tracks = await SpotApi.getPlaylistTracks(spotifyId);
    await _save(playlist.copyWith(tracks: tracks));
    notifyListeners();
  }
}
