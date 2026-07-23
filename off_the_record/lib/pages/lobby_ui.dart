import 'package:flutter/material.dart';

import 'package:off_the_record/audio/spotify_playback.dart';
import 'package:off_the_record/game/game_session.dart';
import 'package:off_the_record/net/game_client.dart';
import 'package:off_the_record/net/host_server.dart';
import 'package:off_the_record/net/protocol.dart';
import 'package:off_the_record/pages/host_console_ui.dart';
import 'package:off_the_record/pages/join_qr_card.dart';
import 'package:off_the_record/pages/player_game_ui.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/palette.dart';

const _roundDurationOptions = [15, 30, 45, 60];
const _roundCountOptions = [5, 10, 15, 20];

class LobbyPage extends StatefulWidget {
  final bool isHost;

  /// Required (and already joined) when [isHost] is false.
  final GameClient? client;

  const LobbyPage({super.key, required this.isHost, this.client})
      : assert(isHost || client != null, 'Player lobby requires a connected GameClient');

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  HostServer? _server;
  String? _errorMessage;
  LocalPlaylist? _selectedPlaylist;
  bool _navigatedToGame = false;
  bool _serverOwnershipTransferred = false;
  bool _randomSeek = false;
  int _roundCount = 10;

  /// Pre-game readiness check (OffTheRecord_HANDOFF.md §4b) so a lobby doesn't
  /// start and then stall on the first song. Connecting here rather than in the
  /// console also means the App Remote handshake — which can bounce the host
  /// out to the Spotify app — happens before players are waiting on a timer.
  /// The live connection is handed to [HostConsolePage] on start.
  SpotifyPlayback? _playback;
  bool _checkingSpotify = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _server = HostServer()..addListener(_onChanged);
      _startServer();
      _playback = SpotifyPlayback();
      _checkSpotifyReady();
    } else {
      widget.client!.addListener(_onChanged);
    }
  }

  Future<void> _checkSpotifyReady() async {
    setState(() => _checkingSpotify = true);
    await _playback!.connect();
    if (!mounted) return;
    setState(() => _checkingSpotify = false);
  }

  Future<void> _startServer() async {
    try {
      await _server!.start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to start lobby: $e');
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (!widget.isHost && !_navigatedToGame && widget.client!.phase != ClientGamePhase.lobby) {
      _navigatedToGame = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PlayerGamePage(client: widget.client!)),
      );
    }
  }

  void _startGame() {
    final playlist = _selectedPlaylist;
    if (playlist == null || playlist.tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a playlist with at least one track first')),
      );
      return;
    }
    final session = GameSession(
      server: _server!,
      playlist: playlist,
      roundDurationMs: _server!.roundDurationSeconds * 1000,
      maxRounds: _roundCount,
    );
    _serverOwnershipTransferred = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HostConsolePage(
          session: session,
          randomSeek: _randomSeek,
          playback: _playback,
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.isHost) {
      _server?.removeListener(_onChanged);
      if (!_serverOwnershipTransferred) {
        _server?.dispose();
        // The console takes over the connection on start; only tear it down
        // when the host backs out of the lobby instead.
        _playback?.disconnect();
      }
    } else {
      widget.client?.removeListener(_onChanged);
    }
    super.dispose();
  }

  List<PlayerInfo> get _players =>
      widget.isHost ? (_server?.players ?? const []) : widget.client!.players;

  String get _roomCode =>
      widget.isHost ? _server!.roomCode : (widget.client!.roomCode ?? '----');

  Future<void> _pickPlaylist() async {
    final playlists = playlistRepository.playlists;
    final selected = await showModalBottomSheet<LocalPlaylist>(
      context: context,
      backgroundColor: OtrColors.surfaceRaised,
      builder: (ctx) => SafeArea(
        child: playlists.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No playlists yet. Add one from the Playlists tab first.',
                  style: TextStyle(color: OtrColors.textMuted),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: playlists.map((p) {
                  return ListTile(
                    leading: const Icon(Icons.queue_music, color: OtrColors.textSecondary),
                    title: Text(p.name, style: const TextStyle(color: OtrColors.textPrimary)),
                    subtitle: Text(
                      '${p.tracks.length} tracks',
                      style: const TextStyle(color: OtrColors.textMuted, fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                }).toList(),
              ),
      ),
    );
    if (selected == null) return;
    setState(() => _selectedPlaylist = selected);
  }

  /// Warns when the chosen playlist can't fill the selected round count.
  String? get _shortPlaylistNotice {
    final tracks = _selectedPlaylist?.tracks.length;
    if (tracks == null || tracks >= _roundCount) return null;
    return 'This playlist only has $tracks track${tracks == 1 ? '' : 's'} — '
        'the game will end after $tracks round${tracks == 1 ? '' : 's'}.';
  }

  /// §4b pre-game readiness: Spotify must be reachable before the first song,
  /// otherwise the lobby starts and immediately stalls.
  Widget _spotifyReadinessBanner() {
    final connected = _playback?.isConnected ?? false;
    final Color accent;
    final String label;
    if (_checkingSpotify) {
      accent = OtrColors.textMuted;
      label = 'Checking Spotify…';
    } else if (connected) {
      accent = OtrColors.cyan;
      label = 'Spotify connected — ready to play';
    } else {
      accent = OtrColors.amber;
      label = 'Spotify not connected. Open Spotify (Premium), then retry — '
          'or make sure the playlist is downloaded for offline play.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: connected ? OtrColors.cyanTintBg : OtrColors.amberTintBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_checkingSpotify)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: OtrColors.textMuted),
            )
          else
            Icon(connected ? Icons.check_circle : Icons.warning_amber_rounded,
                color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: connected ? OtrColors.cyanTintText : OtrColors.amberTintText,
                fontSize: 12,
              ),
            ),
          ),
          if (!_checkingSpotify && !connected)
            TextButton(
              onPressed: _checkSpotifyReady,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(color: OtrColors.amber, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// §8.4: the host device is the answer key — the same warning the DJ console
  /// carries, shown here before anyone is looking over a shoulder.
  Widget _spoilerWarning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.visibility_off, color: OtrColors.textDisabled, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'This phone is the answer key — it shows every title and cover. '
            'Keep it facing you.',
            style: const TextStyle(color: OtrColors.textDisabled, fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtrColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      const Text(
                        "LOBBY",
                        style: TextStyle(
                          color: OtrColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_roomCode.length.clamp(4, 6), (i) {
                          final digit = i < _roomCode.length ? _roomCode[i] : '-';
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 52,
                            height: 60,
                            decoration: BoxDecoration(
                              color: OtrColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: OtrColors.magenta, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              digit,
                              style: const TextStyle(
                                color: OtrColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (widget.isHost && _server != null && _server!.isRunning) ...[
                        const SizedBox(height: 14),
                        JoinQrCard(gamePayload: _server!.qrPayload),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: OtrColors.dangerRed, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: OtrColors.surfaceRaised,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Settings and the player list share one scroll area:
                      // the host settings block is tall enough that a fixed
                      // header would overflow short screens.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                      if (widget.isHost)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _spotifyReadinessBanner(),
                              const SizedBox(height: 12),
                              _spoilerWarning(),
                              const SizedBox(height: 16),
                              const Text(
                                "Playlist",
                                style: TextStyle(
                                  color: OtrColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickPlaylist,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: OtrColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: OtrColors.borderDim, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 14),
                                      const Icon(Icons.queue_music, color: OtrColors.textSecondary, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedPlaylist?.name ?? "Select a playlist...",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _selectedPlaylist != null
                                                ? OtrColors.textPrimary
                                                : OtrColors.textMuted,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down, color: OtrColors.textMuted),
                                      const SizedBox(width: 12),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Round length",
                                style: TextStyle(
                                  color: OtrColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: _roundDurationOptions.map((seconds) {
                                  final selected = _server?.roundDurationSeconds == seconds;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('${seconds}s'),
                                      selected: selected,
                                      onSelected: (_) => setState(() => _server?.setRoundDuration(seconds)),
                                      backgroundColor: OtrColors.surfaceAlt,
                                      selectedColor: OtrColors.magenta,
                                      labelStyle: TextStyle(
                                        color: selected ? OtrColors.onMagenta : OtrColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide.none,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Songs per game",
                                style: TextStyle(
                                  color: OtrColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: _roundCountOptions.map((count) {
                                  final selected = _roundCount == count;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('$count'),
                                      selected: selected,
                                      onSelected: (_) => setState(() => _roundCount = count),
                                      backgroundColor: OtrColors.surfaceAlt,
                                      selectedColor: OtrColors.magenta,
                                      labelStyle: TextStyle(
                                        color: selected ? OtrColors.onMagenta : OtrColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide.none,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_shortPlaylistNotice != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _shortPlaylistNotice!,
                                  style: const TextStyle(color: OtrColors.amber, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Random start point",
                                      style: TextStyle(color: OtrColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                  Switch(
                                    value: _randomSeek,
                                    onChanged: (v) => setState(() => _randomSeek = v),
                                    activeThumbColor: OtrColors.magenta,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Players (${_players.length})",
                            style: const TextStyle(
                              color: OtrColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      if (_players.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              "Waiting for players to join...",
                              style: TextStyle(color: OtrColors.textMuted),
                            ),
                          ),
                        )
                      else
                        ..._players.map(
                          (player) => Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: OtrColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                color: OtrColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                          ],
                        ),
                      ),
                      if (widget.isHost)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OtrColors.magenta,
                                foregroundColor: OtrColors.onMagenta,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                "START",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Text(
                            "Waiting for host to start...",
                            style: TextStyle(color: OtrColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: OtrColors.surfaceRaised,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: OtrColors.textPrimary, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
