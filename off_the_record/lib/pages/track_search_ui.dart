import 'dart:async';

import 'package:flutter/material.dart';

import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/palette.dart';

/// Spotify track search for building custom playlists (handoff §5).
///
/// Spotify-authenticated users only — local-save users have no search and can
/// only reorder/remove tracks from premades and imports.
class TrackSearchPage extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const TrackSearchPage({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<TrackSearchPage> createState() => _TrackSearchPageState();
}

class _TrackSearchPageState extends State<TrackSearchPage> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _debounceTimer;
  List<LocalTrack> _results = const [];
  bool _searching = false;
  String? _error;

  /// Monotonic counter so a slow earlier request can't overwrite newer results.
  int _requestId = 0;

  /// Track IDs already in the playlist, plus ones added in this session.
  late Set<String> _added = _currentTrackIds();

  Set<String> _currentTrackIds() {
    for (final p in playlistRepository.playlists) {
      if (p.id == widget.playlistId) {
        return p.tracks.map((t) => t.spotifyTrackId).toSet();
      }
    }
    return {};
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounceTimer = Timer(_debounce, () => _search(value));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await SpotApi.searchTracks(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Search failed: $e';
        _searching = false;
      });
    }
  }

  Future<void> _add(LocalTrack track) async {
    try {
      await playlistRepository.addTrack(widget.playlistId, track);
      if (!mounted) return;
      setState(() => _added = _currentTrackIds());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add track: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtrColors.background,
      appBar: AppBar(
        backgroundColor: OtrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: OtrColors.textPrimary),
        title: Text(
          'Add to ${widget.playlistName}',
          style: const TextStyle(color: OtrColors.textPrimary, fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(color: OtrColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search Spotify for a song…',
                hintStyle: const TextStyle(color: OtrColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: OtrColors.textMuted),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: OtrColors.textMuted),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
                filled: true,
                fillColor: OtrColors.surfaceRaised,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: OtrColors.borderDim),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: OtrColors.magenta, width: 1.5),
                ),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(color: OtrColors.magenta, minHeight: 2),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OtrColors.dangerRed),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? 'Search Spotify to add tracks to this playlist.'
              : (_searching ? 'Searching…' : 'No matches.'),
          style: const TextStyle(color: OtrColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final track = _results[i];
        final added = _added.contains(track.spotifyTrackId);
        return ListTile(
          leading: _art(track),
          title: Text(
            track.title,
            style: const TextStyle(color: OtrColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artist,
            style: const TextStyle(color: OtrColors.textMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: added
              ? const Icon(Icons.check_circle, color: OtrColors.cyan)
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: OtrColors.magenta),
                  onPressed: () => _add(track),
                ),
          onTap: added ? null : () => _add(track),
        );
      },
    );
  }

  Widget _art(LocalTrack track) {
    if (track.albumArtUrl == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: OtrColors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: OtrColors.textMuted, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        track.albumArtUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 44,
          height: 44,
          color: OtrColors.surfaceAlt,
          child: const Icon(Icons.music_note, color: OtrColors.textMuted, size: 20),
        ),
      ),
    );
  }
}
