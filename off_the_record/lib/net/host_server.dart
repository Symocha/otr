import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'network_utils.dart';
import 'protocol.dart';

class _ConnectedPlayer {
  final String id;
  String name;
  int score = 0;
  WebSocket? socket;
  int missedPongs = 0;

  _ConnectedPlayer({required this.id, required this.name});
}

/// Runs the in-app WebSocket server that acts as the authoritative game
/// state holder while a lobby/game is live. See OffTheRecord_HANDOFF.md §4.
class HostServer extends ChangeNotifier {
  static const _candidatePorts = [4545, 4546, 4547, 0];
  static const _keepAliveInterval = Duration(seconds: 10);
  static const _maxMissedPongs = 3;

  HttpServer? _server;
  Timer? _keepAliveTimer;
  final Map<String, _ConnectedPlayer> _players = {};

  String? ip;
  int? port;
  final String roomCode = generateRoomCode();
  int roundDurationSeconds;

  /// Invoked for every inbound [GuessMessage]; wired up by [GameSession].
  ValueChanged<GuessMessage>? onGuess;

  HostServer({this.roundDurationSeconds = 30});

  bool get isRunning => _server != null;

  void setRoundDuration(int seconds) {
    roundDurationSeconds = seconds;
    notifyListeners();
  }

  List<PlayerInfo> get players =>
      _players.values.map((p) => PlayerInfo(id: p.id, name: p.name, score: p.score)).toList();

  /// JSON payload encoded into the join QR code.
  String get qrPayload => jsonEncode({'v': 1, 'ip': ip, 'port': port, 'room': roomCode});

  Future<void> start() async {
    ip = await resolveLocalIp();

    for (final candidate in _candidatePorts) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, candidate);
        port = _server!.port;
        break;
      } on SocketException {
        continue;
      }
    }
    if (_server == null) {
      throw StateError('Could not bind a host server port');
    }

    _server!.listen(_handleRequest);
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) => _sendKeepAlive());
    notifyListeners();
  }

  Future<void> stop() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    for (final player in _players.values) {
      await player.socket?.close();
    }
    _players.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen(
      (raw) => _handleMessage(socket, raw as String),
      onDone: () => _handleDisconnect(socket),
      onError: (_) => _handleDisconnect(socket),
      cancelOnError: true,
    );
  }

  void _handleMessage(WebSocket socket, String raw) {
    GameMessage message;
    try {
      message = GameMessage.decode(raw);
    } catch (_) {
      return;
    }

    if (message is JoinMessage) {
      _handleJoin(socket, message);
    } else if (message is PongMessage) {
      _handlePong(socket);
    } else if (message is GuessMessage) {
      onGuess?.call(message);
    }
  }

  void _handleJoin(WebSocket socket, JoinMessage message) {
    if (message.room.toUpperCase() != roomCode) {
      socket.add(ErrorMessage(message: 'Wrong room code').encode());
      return;
    }

    final normalizedName = message.name.trim().toLowerCase();
    _ConnectedPlayer? existing;
    for (final p in _players.values) {
      if (p.name.trim().toLowerCase() == normalizedName) {
        existing = p;
        break;
      }
    }

    final player = existing ?? _ConnectedPlayer(id: generatePlayerId(), name: message.name);
    player.name = message.name;
    player.socket = socket;
    player.missedPongs = 0;
    _players[player.id] = player;

    socket.add(JoinedMessage(playerId: player.id, roundDuration: roundDurationSeconds).encode());
    _broadcastPlayerList();
    notifyListeners();
  }

  void _handlePong(WebSocket socket) {
    for (final player in _players.values) {
      if (player.socket == socket) {
        player.missedPongs = 0;
        return;
      }
    }
  }

  void _handleDisconnect(WebSocket socket) {
    var changed = false;
    for (final player in _players.values) {
      if (player.socket == socket) {
        player.socket = null;
        changed = true;
        break;
      }
    }
    if (changed) {
      _broadcastPlayerList();
      notifyListeners();
    }
  }

  void _sendKeepAlive() {
    final dropped = <String>[];
    for (final player in _players.values) {
      final socket = player.socket;
      if (socket == null) continue;
      if (player.missedPongs >= _maxMissedPongs) {
        dropped.add(player.id);
        continue;
      }
      player.missedPongs++;
      try {
        socket.add(PingMessage().encode());
      } catch (_) {
        dropped.add(player.id);
      }
    }

    if (dropped.isEmpty) return;
    for (final id in dropped) {
      _players[id]?.socket?.close();
      _players[id]?.socket = null;
    }
    _broadcastPlayerList();
    notifyListeners();
  }

  void _broadcastPlayerList() {
    final encoded = PlayerListMessage(players: players).encode();
    for (final player in _players.values) {
      player.socket?.add(encoded);
    }
  }

  /// Re-broadcasts the current player list (with up-to-date scores) to all
  /// connected players. Called by [GameSession] after scoring so `player_list`
  /// stays the single channel scores travel over.
  void syncPlayerList() => _broadcastPlayerList();

  void broadcast(GameMessage message) {
    final encoded = message.encode();
    for (final player in _players.values) {
      player.socket?.add(encoded);
    }
  }

  void sendTo(String playerId, GameMessage message) {
    _players[playerId]?.socket?.add(message.encode());
  }

  void addScore(String playerId, int points) {
    final player = _players[playerId];
    if (player == null) return;
    player.score += points;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
