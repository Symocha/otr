import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:off_the_record/audio/spotify_playback.dart';
import 'package:off_the_record/game/game_session.dart';
import 'package:off_the_record/net/protocol.dart';
import 'package:off_the_record/shell/mainShell.dart';
import 'package:off_the_record/theme/palette.dart';

/// Host DJ console — stationary, glanceable, viewed at arm's length. The
/// host is the answer key: title/artist are visible here, never sent to
/// players (see OffTheRecord_HANDOFF.md §8.1/§8.4).
class HostConsolePage extends StatefulWidget {
  final GameSession session;

  /// Seeks to a random point in each track for extra difficulty (§7).
  /// Silently ignored for tracks with unknown duration.
  final bool randomSeek;

  const HostConsolePage({super.key, required this.session, this.randomSeek = false});

  @override
  State<HostConsolePage> createState() => _HostConsolePageState();
}

class _HostConsolePageState extends State<HostConsolePage> {
  Timer? _tick;
  final _playback = SpotifyPlayback();
  bool _spotifyConnecting = true;
  int? _lastPlaybackRoundIndex;
  bool _revealPaused = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onChanged);
    widget.session.start();
    _playback.addListener(_onChanged);
    _connectPlayback();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _connectPlayback() async {
    final ok = await _playback.connect();
    _spotifyConnecting = false;
    if (mounted) setState(() {});
    if (ok) _syncPlaybackToRound();
  }

  Future<void> _retryConnection() async {
    final ok = await _playback.connect();
    if (!ok || !mounted) return;
    final track = widget.session.currentTrack;
    if (track != null) await _playback.play(track.spotifyTrackId);
    widget.session.resume();
  }

  void _syncPlaybackToRound() {
    final session = widget.session;
    if (!_playback.isConnected) return;

    if (session.status == GameStatus.playing) {
      if (_lastPlaybackRoundIndex == session.currentRoundIndex) return;
      _lastPlaybackRoundIndex = session.currentRoundIndex;
      _revealPaused = false;
      final track = session.currentTrack;
      if (track == null) return;

      int? seekToMs;
      final duration = track.durationMs;
      if (widget.randomSeek && duration != null && duration > session.roundDurationMs) {
        seekToMs = Random().nextInt(duration - session.roundDurationMs);
      }
      _playback.play(track.spotifyTrackId, seekToMs: seekToMs).then((ok) {
        if (!ok && mounted && !widget.session.isPaused) widget.session.pause();
      });
    } else if (!_revealPaused) {
      _revealPaused = true;
      _playback.pause();
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _syncPlaybackToRound();
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.session.removeListener(_onChanged);
    _playback.removeListener(_onChanged);
    _playback.disconnect();
    super.dispose();
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('End game?', style: TextStyle(color: OtrColors.textPrimary)),
        content: const Text(
          'This ends the lobby for every player.',
          style: TextStyle(color: OtrColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: OtrColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              widget.session.dispose();
              widget.session.server.dispose();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainShell()),
                (route) => false,
              );
            },
            child: const Text('End game', style: TextStyle(color: OtrColors.dangerRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      backgroundColor: OtrColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OtrColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.server.roomCode,
                      style: const TextStyle(
                        color: OtrColors.textPrimary,
                        fontSize: 17,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.wifi, size: 14, color: OtrColors.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    '${session.server.players.length} players',
                    style: const TextStyle(color: OtrColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: _confirmLeave,
                    child: const Icon(Icons.close, size: 18, color: OtrColors.textMuted),
                  ),
                ],
              ),
            ),
            if (!_spotifyConnecting && !_playback.isConnected && session.status != GameStatus.ended)
              _reconnectBanner(),
            Expanded(child: _buildBody(session)),
          ],
        ),
      ),
    );
  }

  Widget _reconnectBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OtrColors.amberTintBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OtrColors.amberTintBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: OtrColors.amber, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Spotify not connected — rounds are running without music',
              style: TextStyle(color: OtrColors.amberTintText, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _retryConnection,
            child: const Text('Retry', style: TextStyle(color: OtrColors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(GameSession session) {
    switch (session.status) {
      case GameStatus.playing:
        return _buildRoundView(session);
      case GameStatus.revealing:
        return _buildRevealView(session);
      case GameStatus.ended:
        return _buildFinalView(session);
    }
  }

  Widget _buildRoundView(GameSession session) {
    final track = session.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final remainingSeconds = (session.remainingMs / 1000).ceil();
    final fraction = session.roundDurationMs == 0 ? 0.0 : session.remainingMs / session.roundDurationMs;
    final urgent = remainingSeconds <= 5;
    final timerColor = urgent ? OtrColors.dangerRed : OtrColors.magenta;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: OtrColors.purple, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.album, color: OtrColors.onPurple, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: OtrColors.textPrimary, fontSize: 19)),
                    const SizedBox(height: 2),
                    Text(track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: OtrColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(Icons.visibility_off_outlined, size: 13, color: OtrColors.textDisabled),
              SizedBox(width: 5),
              Text('hidden from players', style: TextStyle(color: OtrColors.textDisabled, fontSize: 11)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Text(
                '$remainingSeconds',
                style: TextStyle(color: timerColor, fontSize: 40, fontWeight: FontWeight.w700, height: 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 10,
                    color: OtrColors.trackInactive,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(color: timerColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${session.currentRoundIndex + 1}/${session.totalRounds}',
                  style: const TextStyle(color: OtrColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('live guesses', style: TextStyle(color: OtrColors.textDisabled, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: session.guessFeed.isEmpty
              ? const Center(
                  child: Text('Guesses will show up here', style: TextStyle(color: OtrColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: session.guessFeed.length,
                  itemBuilder: (context, i) => _guessRow(session.guessFeed[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _pauseButton(session)),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: session.skipRound,
                    icon: const Icon(Icons.skip_next, color: OtrColors.onMagenta, size: 19),
                    label: const Text('skip', style: TextStyle(color: OtrColors.onMagenta, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OtrColors.magenta,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pauseButton(GameSession session) {
    final paused = session.isPaused;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _togglePause,
        icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: OtrColors.textSecondary, size: 19),
        label: Text(paused ? 'resume' : 'pause', style: const TextStyle(color: OtrColors.textSecondary, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          backgroundColor: OtrColors.surfaceRaised,
          side: const BorderSide(color: OtrColors.borderDim, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _togglePause() {
    final session = widget.session;
    if (session.isPaused) {
      session.resume();
      if (_playback.isConnected) {
        final track = session.currentTrack;
        if (track != null) _playback.play(track.spotifyTrackId);
      }
    } else {
      session.pause();
      if (_playback.isConnected) _playback.pause();
    }
  }

  Widget _guessRow(GuessFeedItem item) {
    final Color accent;
    final Color nameColor;
    final Color textColor;
    final Color bg;
    final String trailing;
    final Color trailingColor;
    if (item.correct) {
      accent = OtrColors.cyan;
      nameColor = OtrColors.cyan;
      textColor = OtrColors.cyanTintText;
      bg = OtrColors.cyanTintBg;
      trailing = '+${item.pointsAwarded}';
      trailingColor = OtrColors.cyan;
    } else if (item.closeEnough) {
      accent = OtrColors.amber;
      nameColor = OtrColors.amber;
      textColor = OtrColors.amberTintText;
      bg = OtrColors.amberTintBg;
      trailing = 'close';
      trailingColor = OtrColors.amber;
    } else {
      accent = OtrColors.borderDim;
      nameColor = OtrColors.nameNeutral;
      textColor = OtrColors.textDisabled;
      bg = OtrColors.surfaceRaised;
      trailing = 'no';
      trailingColor = OtrColors.textDisabled;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: [
                TextSpan(text: item.playerName, style: TextStyle(color: nameColor, fontSize: 15)),
                TextSpan(text: '  ${item.text}', style: TextStyle(color: textColor, fontSize: 15)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: TextStyle(color: trailingColor, fontSize: item.correct ? 14 : 12)),
        ],
      ),
    );
  }

  Widget _buildRevealView(GameSession session) {
    final result = session.lastRoundEnd;
    if (result == null) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: ValueKey(session.currentRoundIndex),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: OtrColors.purple,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: OtrColors.purple.withValues(alpha: 0.5), blurRadius: 30)],
              ),
              child: const Icon(Icons.music_note, color: OtrColors.textPrimary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(result.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: OtrColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(result.artist,
                textAlign: TextAlign.center, style: const TextStyle(color: OtrColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 24),
            Expanded(child: _leaderboard(result.leaderboard)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalView(GameSession session) {
    final result = session.finalResult;
    if (result == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Expanded(child: _leaderboard(result.finalLeaderboard)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                session.dispose();
                session.server.dispose();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: OtrColors.magenta,
                foregroundColor: OtrColors.onMagenta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboard(List<PlayerInfo> players) {
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isTop = i == 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isTop ? OtrColors.cyanTintBg : OtrColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isTop
                ? [BoxShadow(color: OtrColors.cyan.withValues(alpha: 0.3), blurRadius: 16)]
                : null,
          ),
          child: Row(
            children: [
              Text('#${i + 1}',
                  style: TextStyle(
                      color: isTop ? OtrColors.cyan : OtrColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(color: OtrColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              Text('${p.score}',
                  style: TextStyle(
                      color: isTop ? OtrColors.cyan : OtrColors.textSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
