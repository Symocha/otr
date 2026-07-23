import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/pages/track_search_ui.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/palette.dart';

class PlaylistDetailPage extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  bool _spotifySignedIn = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    playlistRepository.addListener(_onChanged);
    _checkSignedIn();
  }

  @override
  void dispose() {
    playlistRepository.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _checkSignedIn() async {
    final signedIn = await SpotApi.isSignedIn();
    if (mounted) setState(() => _spotifySignedIn = signedIn);
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
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('Rename playlist', style: TextStyle(color: OtrColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: OtrColors.textPrimary),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: OtrColors.borderDim),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: OtrColors.magenta),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: OtrColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: OtrColors.magenta, fontWeight: FontWeight.w600),
            ),
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

  void _openSearch(LocalPlaylist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackSearchPage(
          playlistId: playlist.id,
          playlistName: playlist.name,
        ),
      ),
    );
  }

  /// Handoff §5: collaboration is Spotify's, not ours. This pushes the local
  /// playlist up as a collaborative Spotify playlist; friends edit it in
  /// Spotify and pull-to-refresh brings their changes back.
  Future<void> _makeCollaborative(LocalPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('Make collaborative', style: TextStyle(color: OtrColors.textPrimary)),
        content: const Text(
          'This creates a private, collaborative playlist on your Spotify '
          'account with these tracks. Share the link and friends can add songs '
          'in Spotify — pull down here to sync their changes back.',
          style: TextStyle(color: OtrColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: OtrColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Create',
              style: TextStyle(color: OtrColors.magenta, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _publishing = true);
    try {
      final linked = await playlistRepository.publishAsCollaborative(playlist.id);
      if (!mounted) return;
      _showShareLink(SpotApi.playlistShareUrl(linked.spotifyPlaylistId!));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make it collaborative: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showShareLink(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('Invite collaborators', style: TextStyle(color: OtrColors.textPrimary)),
        content: SelectableText(
          url,
          style: const TextStyle(color: OtrColors.cyan, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: OtrColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Copy link',
              style: TextStyle(color: OtrColors.magenta, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    if (playlist == null) {
      return const Scaffold(
        backgroundColor: OtrColors.background,
        body: Center(
          child: Text('Playlist not found', style: TextStyle(color: OtrColors.textMuted)),
        ),
      );
    }

    final canEdit = !playlist.isPremade;
    return Scaffold(
      backgroundColor: OtrColors.background,
      appBar: AppBar(
        backgroundColor: OtrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: OtrColors.textPrimary),
        title: Text(playlist.name, style: const TextStyle(color: OtrColors.textPrimary)),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit, color: OtrColors.textSecondary),
              onPressed: () => _rename(playlist),
            ),
          if (canEdit && _spotifySignedIn && playlist.spotifyPlaylistId == null)
            IconButton(
              tooltip: 'Make collaborative',
              icon: const Icon(Icons.group_add, color: OtrColors.textSecondary),
              onPressed: _publishing ? null : () => _makeCollaborative(playlist),
            ),
          if (playlist.spotifyPlaylistId != null)
            IconButton(
              tooltip: 'Copy Spotify link',
              icon: const Icon(Icons.link, color: OtrColors.cyan),
              onPressed: () =>
                  _showShareLink(SpotApi.playlistShareUrl(playlist.spotifyPlaylistId!)),
            ),
        ],
      ),
      floatingActionButton: (canEdit && _spotifySignedIn)
          ? FloatingActionButton.extended(
              onPressed: () => _openSearch(playlist),
              backgroundColor: OtrColors.magenta,
              foregroundColor: OtrColors.onMagenta,
              icon: const Icon(Icons.search),
              label: const Text('Add tracks', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          if (_publishing) const LinearProgressIndicator(color: OtrColors.magenta, minHeight: 2),
          _notice(playlist),
          Expanded(child: _buildList(playlist)),
        ],
      ),
    );
  }

  Widget _notice(LocalPlaylist playlist) {
    final String? text;
    if (playlist.isPremade) {
      text = 'Premade playlists are read-only. Duplicate it from the playlist '
          'list to reorder or remove tracks.';
    } else if (!_spotifySignedIn) {
      text = 'Sign in with Spotify to search and add new tracks. For now you '
          'can reorder or remove existing tracks.';
    } else if (playlist.spotifyPlaylistId != null) {
      text = 'Collaborators edit this in Spotify — pull down to sync their changes.';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        text,
        style: const TextStyle(color: OtrColors.textMuted, fontSize: 13),
      ),
    );
  }

  Widget _buildList(LocalPlaylist playlist) {
    if (playlist.tracks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tracks yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OtrColors.textMuted),
          ),
        ),
      );
    }

    if (playlist.isPremade) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: playlist.tracks.length,
        itemBuilder: (context, i) => _trackTile(playlist.tracks[i]),
      );
    }

    final reorderable = ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
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
            color: OtrColors.dangerRed,
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
    return RefreshIndicator(
      onRefresh: _refresh,
      color: OtrColors.magenta,
      backgroundColor: OtrColors.surfaceRaised,
      child: reorderable,
    );
  }

  Widget _trackTile(LocalTrack track) {
    return ListTile(
      key: ValueKey('tile-${track.spotifyTrackId}'),
      leading: track.albumArtUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                track.albumArtUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _artPlaceholder(),
              ),
            )
          : _artPlaceholder(),
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
    );
  }

  Widget _artPlaceholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: OtrColors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: OtrColors.textMuted, size: 20),
      );
}
