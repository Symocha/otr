import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'protocol.dart';

enum ClientGamePhase { lobby, round, reveal, ended }

/// Player-side connection to a lobby's [HostServer]. See
/// OffTheRecord_HANDOFF.md §4.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Completer<JoinedMessage>? _joinCompleter;

  String? playerId;
  String? roomCode;
  int roundDurationSeconds = 30;
  List<PlayerInfo> players = [];
  String? lastError;
  bool disconnected = false;

  ClientGamePhase phase = ClientGamePhase.lobby;
  RoundStartMessage? currentRound;
  GuessResultMessage? lastGuessResult;
  RoundEndMessage? lastRoundEnd;
  GameEndMessage? finalResult;

  /// Aggregate-only "N players already nailed it" ticker — never carries
  /// guess content (see OffTheRecord_HANDOFF.md §8.4).
  int scoredCount = 0;

  bool get isConnected => _channel != null && !disconnected;

  Future<void> connect(String ip, int port) async {
    _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));
    await _channel!.ready;
    _subscription = _channel!.stream.listen(
      (raw) => _handleMessage(raw as String),
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
  }

  /// Sends the join request and resolves once the host acks (or rejects).
  Future<JoinedMessage> join(String room, String name) {
    final completer = Completer<JoinedMessage>();
    _joinCompleter = completer;
    roomCode = room;
    _channel?.sink.add(JoinMessage(room: room, name: name).encode());
    return completer.future;
  }

  void sendGuess(String text) {
    final id = playerId;
    if (id == null) return;
    _channel?.sink.add(GuessMessage(
      playerId: id,
      text: text,
      clientSentAtMs: DateTime.now().millisecondsSinceEpoch,
    ).encode());
  }

  void _handleMessage(String raw) {
    GameMessage message;
    try {
      message = GameMessage.decode(raw);
    } catch (_) {
      return;
    }

    if (message is JoinedMessage) {
      playerId = message.playerId;
      roundDurationSeconds = message.roundDuration;
      _joinCompleter?.complete(message);
      _joinCompleter = null;
      notifyListeners();
    } else if (message is PlayerListMessage) {
      players = message.players;
      notifyListeners();
    } else if (message is ErrorMessage) {
      lastError = message.message;
      if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.completeError(message.message);
        _joinCompleter = null;
      }
      notifyListeners();
    } else if (message is PingMessage) {
      _channel?.sink.add(PongMessage().encode());
    } else if (message is RoundStartMessage) {
      currentRound = message;
      lastGuessResult = null;
      scoredCount = 0;
      phase = ClientGamePhase.round;
      notifyListeners();
    } else if (message is RoundProgressMessage) {
      scoredCount = message.scoredCount;
      notifyListeners();
    } else if (message is GuessResultMessage) {
      lastGuessResult = message;
      notifyListeners();
    } else if (message is RoundEndMessage) {
      lastRoundEnd = message;
      phase = ClientGamePhase.reveal;
      notifyListeners();
    } else if (message is GameEndMessage) {
      finalResult = message;
      phase = ClientGamePhase.ended;
      notifyListeners();
    }
  }

  void _handleDisconnect() {
    disconnected = true;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
