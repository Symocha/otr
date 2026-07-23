import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:off_the_record/net/host_server.dart';
import 'package:off_the_record/net/protocol.dart';
import 'package:off_the_record/storage/models.dart';
import 'scoring.dart';

enum GameStatus { playing, revealing, ended }

class GuessFeedItem {
  final String playerName;
  final String text;
  final bool correct;
  final bool closeEnough;
  final int pointsAwarded;

  const GuessFeedItem({
    required this.playerName,
    required this.text,
    required this.correct,
    required this.closeEnough,
    required this.pointsAwarded,
  });
}

const _maxGuessFeedItems = 6;

/// Host-only game state machine: sequences a playlist's tracks into rounds,
/// scores incoming guesses, and drives round/reveal/final broadcasts. See
/// OffTheRecord_HANDOFF.md §6.
class GameSession extends ChangeNotifier {
  final HostServer server;
  final LocalPlaylist playlist;
  final int roundDurationMs;
  final int revealDurationMs;

  late final List<LocalTrack> _order;
  Timer? _roundTimer;
  Timer? _revealTimer;

  GameStatus status = GameStatus.playing;
  int currentRoundIndex = -1;
  int? roundStartedAtMs;
  bool isPaused = false;
  int? _pausedRemainingMs;
  final Set<String> _scoredThisRound = {};
  List<GuessFeedItem> guessFeed = [];
  RoundEndMessage? lastRoundEnd;
  GameEndMessage? finalResult;

  GameSession({
    required this.server,
    required this.playlist,
    this.roundDurationMs = 30000,
    this.revealDurationMs = 6000,
  });

  int get totalRounds => _order.length;

  LocalTrack? get currentTrack =>
      (currentRoundIndex >= 0 && currentRoundIndex < _order.length) ? _order[currentRoundIndex] : null;

  /// Time left in the current round. Frozen while [isPaused] — the single
  /// source of truth both scoring and the host UI's timer display use.
  int get remainingMs {
    if (isPaused) return _pausedRemainingMs ?? 0;
    if (roundStartedAtMs == null) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - roundStartedAtMs!;
    return (roundDurationMs - elapsed).clamp(0, roundDurationMs);
  }

  /// Freezes the round timer (e.g. on a Spotify App Remote disconnect —
  /// see OffTheRecord_HANDOFF.md §7's "pause the game" requirement).
  void pause() {
    if (status != GameStatus.playing || isPaused) return;
    _roundTimer?.cancel();
    _pausedRemainingMs = remainingMs;
    isPaused = true;
    notifyListeners();
  }

  /// Resumes with whatever time was left when [pause] was called.
  void resume() {
    if (!isPaused) return;
    isPaused = false;
    final remaining = _pausedRemainingMs ?? 0;
    roundStartedAtMs = DateTime.now().millisecondsSinceEpoch - (roundDurationMs - remaining);
    _pausedRemainingMs = null;
    _roundTimer = Timer(Duration(milliseconds: remaining), _endRound);
    notifyListeners();
  }

  void start() {
    _order = List.of(playlist.tracks)..shuffle(Random());
    server.onGuess = _handleGuess;
    _startRound(0);
  }

  void _startRound(int index) {
    currentRoundIndex = index;
    status = GameStatus.playing;
    _scoredThisRound.clear();
    guessFeed = [];
    roundStartedAtMs = DateTime.now().millisecondsSinceEpoch;

    server.broadcast(RoundStartMessage(
      roundIndex: index,
      totalRounds: _order.length,
      startedAtMs: roundStartedAtMs!,
      durationMs: roundDurationMs,
    ));
    notifyListeners();

    _roundTimer = Timer(Duration(milliseconds: roundDurationMs), _endRound);
  }

  void _handleGuess(GuessMessage message) {
    if (status != GameStatus.playing) return;
    final track = currentTrack;
    if (track == null) return;

    if (_scoredThisRound.contains(message.playerId)) {
      server.sendTo(
        message.playerId,
        GuessResultMessage(correct: false, closeEnough: false, pointsAwarded: 0),
      );
      return;
    }

    final timeRemainingMs = remainingMs;
    final outcome = computeGuessOutcome(
      message.text,
      track.title,
      timeRemainingMs: timeRemainingMs,
      roundDurationMs: roundDurationMs,
    );

    final playerName = server.players
        .firstWhere((p) => p.id == message.playerId, orElse: () => const PlayerInfo(id: '', name: '?', score: 0))
        .name;
    guessFeed = [
      GuessFeedItem(
        playerName: playerName,
        text: message.text,
        correct: outcome.correct,
        closeEnough: outcome.closeEnough,
        pointsAwarded: outcome.pointsAwarded,
      ),
      ...guessFeed,
    ];
    if (guessFeed.length > _maxGuessFeedItems) {
      guessFeed = guessFeed.sublist(0, _maxGuessFeedItems);
    }

    if (outcome.correct) {
      _scoredThisRound.add(message.playerId);
      server.addScore(message.playerId, outcome.pointsAwarded);
      server.broadcast(RoundProgressMessage(scoredCount: _scoredThisRound.length));
    }

    server.sendTo(
      message.playerId,
      GuessResultMessage(
        correct: outcome.correct,
        closeEnough: outcome.closeEnough,
        pointsAwarded: outcome.pointsAwarded,
      ),
    );
    notifyListeners();
  }

  void skipRound() {
    _roundTimer?.cancel();
    _endRound();
  }

  void _endRound() {
    _roundTimer?.cancel();
    status = GameStatus.revealing;
    final track = currentTrack;
    if (track == null) return;

    final leaderboard = List.of(server.players)..sort((a, b) => b.score.compareTo(a.score));
    final result = RoundEndMessage(title: track.title, artist: track.artist, leaderboard: leaderboard);
    lastRoundEnd = result;
    server.broadcast(result);
    server.syncPlayerList();
    notifyListeners();

    final isLastRound = currentRoundIndex + 1 >= _order.length;
    _revealTimer = Timer(
      Duration(milliseconds: revealDurationMs),
      isLastRound ? _endGame : () => _startRound(currentRoundIndex + 1),
    );
  }

  void _endGame() {
    status = GameStatus.ended;
    final leaderboard = List.of(server.players)..sort((a, b) => b.score.compareTo(a.score));
    finalResult = GameEndMessage(finalLeaderboard: leaderboard);
    server.broadcast(finalResult!);
    notifyListeners();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _revealTimer?.cancel();
    server.onGuess = null;
    super.dispose();
  }
}
