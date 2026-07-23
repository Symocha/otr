import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:off_the_record/net/game_client.dart';
import 'package:off_the_record/net/protocol.dart';
import 'package:off_the_record/shell/mainShell.dart';
import 'package:off_the_record/theme/palette.dart';

class _GuessAttempt {
  final String text;
  GuessResultMessage? result;

  _GuessAttempt(this.text);
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

/// Player guess screen — fast, one-handed, used under time pressure with the
/// keyboard open. The title/artist are never shown here during a round: the
/// protocol simply never sends them (see OffTheRecord_HANDOFF.md §8.1/§8.4).
class PlayerGamePage extends StatefulWidget {
  final GameClient client;

  const PlayerGamePage({super.key, required this.client});

  @override
  State<PlayerGamePage> createState() => _PlayerGamePageState();
}

class _PlayerGamePageState extends State<PlayerGamePage> with SingleTickerProviderStateMixin {
  static const _waveformColors = [
    OtrColors.borderDim,
    OtrColors.purple,
    OtrColors.magenta,
    OtrColors.purple,
    OtrColors.magenta,
    OtrColors.cyan,
    OtrColors.purple,
    OtrColors.magenta,
    OtrColors.cyan,
    OtrColors.borderDim,
    OtrColors.purple,
    OtrColors.magenta,
    OtrColors.purple,
    OtrColors.borderDim,
  ];
  static const _waveformBaseHeights = [
    22.0, 44.0, 64.0, 36.0, 58.0, 70.0, 30.0, 52.0, 66.0, 26.0, 48.0, 60.0, 34.0, 20.0,
  ];

  final _guessController = TextEditingController();
  late final AnimationController _waveController;
  Timer? _tick;
  final List<_GuessAttempt> _history = [];
  int? _historyRoundIndex;

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_onChanged);
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onChanged() {
    if (!mounted) return;
    final client = widget.client;
    final roundIndex = client.currentRound?.roundIndex;
    if (roundIndex != _historyRoundIndex) {
      _historyRoundIndex = roundIndex;
      _history.clear();
    }
    if (client.lastGuessResult != null && _history.isNotEmpty && _history.first.result == null) {
      _history.first.result = client.lastGuessResult;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _waveController.dispose();
    widget.client.removeListener(_onChanged);
    _guessController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _guessController.text.trim();
    if (text.isEmpty) return;
    widget.client.sendGuess(text);
    setState(() {
      _history.insert(0, _GuessAttempt(text));
      if (_history.length > 3) _history.removeLast();
    });
    _guessController.clear();
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OtrColors.surfaceRaised,
        title: const Text('Leave game?', style: TextStyle(color: OtrColors.textPrimary)),
        content: const Text('Your progress will be lost.', style: TextStyle(color: OtrColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: OtrColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              widget.client.disconnect();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainShell()),
                (route) => false,
              );
            },
            child: const Text('Leave', style: TextStyle(color: OtrColors.dangerRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Scaffold(
      backgroundColor: OtrColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _confirmLeave,
                child: const Text('Leave', style: TextStyle(color: OtrColors.dangerRed)),
              ),
            ),
            Expanded(child: _buildBody(client)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GameClient client) {
    switch (client.phase) {
      case ClientGamePhase.round:
        return _buildRoundView(client);
      case ClientGamePhase.reveal:
        return _buildRevealView(client);
      case ClientGamePhase.ended:
        return _buildFinalView(client);
      case ClientGamePhase.lobby:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRoundView(GameClient client) {
    final round = client.currentRound!;
    final elapsed = DateTime.now().millisecondsSinceEpoch - round.startedAtMs;
    final remainingMs = (round.durationMs - elapsed).clamp(0, round.durationMs);
    final remainingSeconds = (remainingMs / 1000).ceil();
    final fraction = round.durationMs == 0 ? 0.0 : remainingMs / round.durationMs;
    final urgent = remainingMs <= 5000;
    final barColor = urgent ? OtrColors.dangerRed : OtrColors.magenta;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final sortedPlayers = List.of(client.players)..sort((a, b) => b.score.compareTo(a.score));
    final myIndex = sortedPlayers.indexWhere((p) => p.id == client.playerId);
    final myScore = myIndex >= 0 ? sortedPlayers[myIndex].score : 0;
    final myRank = myIndex >= 0 ? myIndex + 1 : sortedPlayers.length + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('song ${round.roundIndex + 1} of ${round.totalRounds}',
                  style: const TextStyle(color: OtrColors.textMuted, fontSize: 11)),
              if (sortedPlayers.isNotEmpty)
                Text('$myScore pts · ${_ordinal(myRank)}',
                    style: const TextStyle(color: OtrColors.cyan, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 10,
                    color: OtrColors.trackInactive,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(color: barColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${remainingSeconds}s', style: TextStyle(color: barColor, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          _buildWaveform(),
          const SizedBox(height: 4),
          const Text('what is this song called?', style: TextStyle(color: OtrColors.textMuted, fontSize: 13)),
          if (client.scoredCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: OtrColors.amberTintBg,
                border: Border.all(color: OtrColors.amberTintBorder, width: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${client.scoredCount} ${client.scoredCount == 1 ? 'player' : 'players'} already nailed it',
                style: const TextStyle(color: OtrColors.amber, fontSize: 12),
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(children: _history.take(2).map(_historyRow).toList()),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guessController,
                  style: const TextStyle(color: OtrColors.textPrimary),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Your guess',
                    hintStyle: const TextStyle(color: OtrColors.textMuted),
                    filled: true,
                    fillColor: OtrColors.surfaceRaised,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OtrColors.borderDim),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OtrColors.cyan, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OtrColors.cyan,
                    foregroundColor: OtrColors.onCyan,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.send, size: 20),
                ),
              ),
            ],
          ),
          if (!keyboardOpen) ...[
            const SizedBox(height: 16),
            Expanded(child: _leaderboard(sortedPlayers)),
          ],
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 74,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_waveformBaseHeights.length, (i) {
              final phase = _waveController.value * 2 * pi + i * 0.5;
              final scale = 0.75 + 0.25 * (0.5 + 0.5 * sin(phase));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 6,
                  height: _waveformBaseHeights[i] * scale,
                  decoration: BoxDecoration(
                    color: _waveformColors[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _historyRow(_GuessAttempt attempt) {
    final result = attempt.result;
    Color bg = OtrColors.surfaceRaised;
    Color textColor = OtrColors.textMuted;
    String label = '…';
    Color labelColor = OtrColors.textMuted;
    if (result != null) {
      if (result.correct) {
        bg = OtrColors.cyanTintBg;
        textColor = OtrColors.cyanTintText;
        label = 'correct';
        labelColor = OtrColors.cyan;
      } else if (result.closeEnough) {
        bg = OtrColors.amberTintBg;
        textColor = OtrColors.amberTintText;
        label = 'so close';
        labelColor = OtrColors.amber;
      } else {
        textColor = OtrColors.textDisabled;
        label = 'not it';
        labelColor = OtrColors.textDisabled;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(attempt.text,
                style: TextStyle(color: textColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRevealView(GameClient client) {
    final result = client.lastRoundEnd!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: OtrColors.purple,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: OtrColors.purple.withValues(alpha: 0.5), blurRadius: 24)],
            ),
            child: const Icon(Icons.music_note, color: OtrColors.textPrimary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(result.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OtrColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(result.artist,
              textAlign: TextAlign.center, style: const TextStyle(color: OtrColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(child: _leaderboard(result.leaderboard)),
        ],
      ),
    );
  }

  Widget _buildFinalView(GameClient client) {
    final result = client.finalResult!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          const Text('FINAL SCORES',
              style: TextStyle(color: OtrColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 16),
          Expanded(child: _leaderboard(result.finalLeaderboard)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                client.disconnect();
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
    if (players.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isTop = i == 0;
        final isMe = p.id == widget.client.playerId;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isTop ? OtrColors.cyanTintBg : OtrColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: isMe ? Border.all(color: OtrColors.magenta, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Text('#${i + 1}',
                  style: TextStyle(color: isTop ? OtrColors.cyan : OtrColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(color: OtrColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              Text('${p.score}',
                  style: TextStyle(color: isTop ? OtrColors.cyan : OtrColors.textSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
