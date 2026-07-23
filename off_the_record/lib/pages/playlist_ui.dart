import 'package:flutter/material.dart';

import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/palette.dart';
import 'playlist_detail_ui.dart';

/// Spotify's brand green. Per handoff §8.3 this is the *only* place green is
/// allowed — the app is otherwise deliberately visually distant from Spotify.
const _spotifyGreen = Color(0xFF1DB954);

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  bool _spotifySignedIn = false;

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

  Future<String?> _promptForName({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: Text(title, style: const TextStyle(color: OtrColors.textPrimary)),
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
            child: Text(
              actionLabel,
              style: const TextStyle(color: OtrColors.magenta, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicate(LocalPlaylist playlist) async {
    final name = await _promptForName(
      title: 'Duplicate playlist',
      actionLabel: 'Duplicate',
      initialValue: '${playlist.name} (copy)',
    );
    if (name == null || name.isEmpty) return;
    await playlistRepository.duplicate(playlist.id, newName: name);
  }

  Future<void> _createNew() async {
    final name = await _promptForName(title: 'New playlist', actionLabel: 'Create');
    if (name == null || name.isEmpty) return;
    final playlist = await playlistRepository.create(name);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlistId: playlist.id)),
    );
  }

  Future<void> _importFromSpotify() async {
    List<Map<String, dynamic>> spotifyPlaylists;
    try {
      spotifyPlaylists = await SpotApi.getPlaylists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load Spotify playlists: $e')),
      );
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: OtrColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: spotifyPlaylists.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No playlists on your Spotify account.',
                  style: TextStyle(color: OtrColors.textMuted),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: spotifyPlaylists.map((p) {
                  return ListTile(
                    leading: const Icon(Icons.queue_music, color: OtrColors.textSecondary),
                    title: Text(
                      p['name'] as String? ?? '',
                      style: const TextStyle(color: OtrColors.textPrimary),
                    ),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                }).toList(),
              ),
      ),
    );
    if (selected == null) return;

    try {
      await playlistRepository.importFromSpotify(
        selected['id'] as String,
        name: selected['name'] as String? ?? 'Imported playlist',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(LocalPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('Delete playlist?', style: TextStyle(color: OtrColors.textPrimary)),
        content: Text(
          'Removes "${playlist.name}" from this device. Playlists on your '
          'Spotify account are not affected.',
          style: const TextStyle(color: OtrColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: OtrColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: OtrColors.dangerRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) await playlistRepository.delete(playlist.id);
  }

  ({String label, Color color}) _tagFor(LocalPlaylist p) {
    if (p.isPremade) return (label: 'Premade', color: OtrColors.textMuted);
    if (p.spotifyPlaylistId != null) return (label: 'Synced', color: OtrColors.cyan);
    return (label: 'Local', color: OtrColors.textMuted);
  }

  @override
  Widget build(BuildContext context) {
    final playlists = playlistRepository.playlists;
    return Container(
      color: OtrColors.background,
      child: Column(
        children: [
          Expanded(
            child: playlists.isEmpty
                ? const Center(
                    child: Text('No playlists yet.', style: TextStyle(color: OtrColors.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) => _playlistRow(playlists[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _createNew,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('New'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OtrColors.magenta,
                          foregroundColor: OtrColors.onMagenta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_spotifySignedIn) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _importFromSpotify,
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text('Import'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _spotifyGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playlistRow(LocalPlaylist p) {
    final tag = _tagFor(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OtrColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OtrColors.borderDim, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: OtrColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.queue_music, color: OtrColors.textSecondary),
        ),
        title: Text(
          p.name,
          style: const TextStyle(
            color: OtrColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '${p.tracks.length} tracks',
                style: const TextStyle(color: OtrColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OtrColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag.label,
                  style: TextStyle(color: tag.color, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: OtrColors.surfaceAlt,
          icon: const Icon(Icons.more_vert, color: OtrColors.textMuted),
          onSelected: (action) {
            if (action == 'duplicate') _duplicate(p);
            if (action == 'delete') _confirmDelete(p);
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'duplicate',
              child: Text('Duplicate to edit', style: TextStyle(color: OtrColors.textPrimary)),
            ),
            if (!p.isPremade)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: OtrColors.dangerRed)),
              ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlistId: p.id)),
        ),
      ),
    );
  }
}
