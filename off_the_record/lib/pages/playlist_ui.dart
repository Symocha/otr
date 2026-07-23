import 'package:flutter/material.dart';

import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'playlist_detail_ui.dart';

class playlistPage extends StatefulWidget {
  const playlistPage({super.key});

  @override
  State<playlistPage> createState() => _playlistPageState();
}

class _playlistPageState extends State<playlistPage> {
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

  Future<void> _duplicate(LocalPlaylist playlist) async {
    final controller = TextEditingController(text: '${playlist.name} (copy)');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        title: const Text('Duplicate playlist', style: TextStyle(color: Colors.white)),
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
            child: const Text('Duplicate', style: TextStyle(color: Color(0xFF39D0C6))),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await playlistRepository.duplicate(playlist.id, newName: name);
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
      backgroundColor: const Color(0xFF1A2240),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: spotifyPlaylists.map((p) {
            return ListTile(
              leading: const Icon(Icons.queue_music, color: Color(0xFF39D0C6)),
              title: Text(
                p['name'] as String? ?? '',
                style: const TextStyle(color: Colors.white),
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

  String _subtitleFor(LocalPlaylist p) {
    final tag = p.isPremade ? 'Premade' : (p.spotifyPlaylistId != null ? 'Imported' : 'Local');
    return '${p.tracks.length} tracks · $tag';
  }

  @override
  Widget build(BuildContext context) {
    final playlists = playlistRepository.playlists;
    return Container(
      color: const Color(0xFF151822),
      child: Column(
        children: [
          Expanded(
            child: playlists.isEmpty
                ? const Center(
                    child: Text('No playlists yet.', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) {
                      final p = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music, color: Color(0xFF39D0C6)),
                        title: Text(
                          p.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _subtitleFor(p),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: const Color(0xFF1A2240),
                          icon: const Icon(Icons.more_vert, color: Colors.white54),
                          onSelected: (action) {
                            if (action == 'duplicate') _duplicate(p);
                            if (action == 'delete') playlistRepository.delete(p.id);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Duplicate to edit', style: TextStyle(color: Colors.white)),
                            ),
                            if (!p.isPremade)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlistId: p.id)),
                        ),
                      );
                    },
                  ),
          ),
          FutureBuilder<bool>(
            future: SpotApi.isSignedIn(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _importFromSpotify,
                      icon: const Icon(Icons.add),
                      label: const Text('Import from Spotify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
