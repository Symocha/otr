import 'package:flutter/material.dart';

import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';

class PlaylistDetailPage extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    playlistRepository.addListener(_onChanged);
  }

  @override
  void dispose() {
    playlistRepository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  LocalPlaylist? get _playlist {
    for (final p in playlistRepository.playlists) {
      if (p.id == widget.playlistId) return p;
    }
    return null;
  }

  Future<void> _rename(LocalPlaylist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        title: const Text('Rename playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Color(0xFF39D0C6))),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await playlistRepository.rename(playlist.id, name);
  }

  Future<void> _refresh() async {
    final playlist = _playlist;
    if (playlist?.spotifyPlaylistId == null) return;
    try {
      await playlistRepository.resync(playlist!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    if (playlist == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1530),
        body: Center(
          child: Text('Playlist not found', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1530),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1530),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
        actions: [
          if (!playlist.isPremade)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _rename(playlist),
            ),
        ],
      ),
      body: Column(
        children: [
          if (playlist.isPremade)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Premade playlists are read-only. Duplicate it from the playlist list to reorder or remove tracks.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else if (playlist.spotifyPlaylistId == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Sign in with Spotify to search and add new tracks. For now you can reorder or remove existing tracks.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          Expanded(child: _buildList(playlist)),
        ],
      ),
    );
  }

  Widget _buildList(LocalPlaylist playlist) {
    if (playlist.isPremade) {
      return ListView.builder(
        itemCount: playlist.tracks.length,
        itemBuilder: (context, i) => _trackTile(playlist.tracks[i]),
      );
    }

    final reorderable = ReorderableListView.builder(
      itemCount: playlist.tracks.length,
      onReorderItem: (oldIndex, newIndex) {
        playlistRepository.reorderTracks(playlist.id, oldIndex, newIndex);
      },
      itemBuilder: (context, i) {
        final track = playlist.tracks[i];
        return Dismissible(
          key: ValueKey(track.spotifyTrackId),
          direction: DismissDirection.endToStart,
          background: Container(
            color: const Color(0xFFE05555),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => playlistRepository.removeTrack(playlist.id, track.spotifyTrackId),
          child: _trackTile(track),
        );
      },
    );

    if (playlist.spotifyPlaylistId == null) return reorderable;
    return RefreshIndicator(onRefresh: _refresh, child: reorderable);
  }

  Widget _trackTile(LocalTrack track) {
    return ListTile(
      leading: track.albumArtUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(track.albumArtUrl!, width: 44, height: 44, fit: BoxFit.cover),
            )
          : Container(
              width: 44,
              height: 44,
              color: const Color(0xFF1A2240),
              child: const Icon(Icons.music_note, color: Colors.white38),
            ),
      title: Text(
        track.title,
        style: const TextStyle(color: Colors.white),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        style: const TextStyle(color: Colors.white54),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
