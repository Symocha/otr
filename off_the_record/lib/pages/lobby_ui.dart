import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:off_the_record/game/game_session.dart';
import 'package:off_the_record/net/game_client.dart';
import 'package:off_the_record/net/host_server.dart';
import 'package:off_the_record/net/protocol.dart';
import 'package:off_the_record/pages/host_console_ui.dart';
import 'package:off_the_record/pages/player_game_ui.dart';
import 'package:off_the_record/storage/models.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/palette.dart';

const _roundDurationOptions = [15, 30, 45, 60];

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

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _server = HostServer()..addListener(_onChanged);
      _startServer();
    } else {
      widget.client!.addListener(_onChanged);
    }
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
    );
    _serverOwnershipTransferred = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HostConsolePage(session: session, randomSeek: _randomSeek)),
    );
  }

  @override
  void dispose() {
    if (widget.isHost) {
      _server?.removeListener(_onChanged);
      if (!_serverOwnershipTransferred) {
        _server?.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtrColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
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
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: OtrColors.magenta, width: 2),
                          ),
                          child: QrImageView(
                            data: _server!.qrPayload,
                            size: 120,
                            backgroundColor: Colors.white,
                          ),
                        ),
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
              Expanded(
                flex: 7,
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
                      if (widget.isHost)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                      Expanded(
                        child: _players.isEmpty
                            ? const Center(
                                child: Text(
                                  "Waiting for players to join...",
                                  style: TextStyle(color: OtrColors.textMuted),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _players.length,
                                itemBuilder: (context, index) {
                                  final player = _players[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
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
                                  );
                                },
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
