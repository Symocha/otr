import 'dart:convert';

/// Message type discriminators used on the wire (see OffTheRecord_HANDOFF.md §4).
abstract class MessageType {
  static const join = 'join';
  static const joined = 'joined';
  static const playerList = 'player_list';
  static const roundStart = 'round_start';
  static const roundProgress = 'round_progress';
  static const guess = 'guess';
  static const guessResult = 'guess_result';
  static const roundEnd = 'round_end';
  static const gameEnd = 'game_end';
  static const error = 'error';
  static const ping = 'ping';
  static const pong = 'pong';
}

abstract class GameMessage {
  String get type;

  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());

  static GameMessage decode(String raw) => fromJson(jsonDecode(raw) as Map<String, dynamic>);

  static GameMessage fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case MessageType.join:
        return JoinMessage.fromJson(json);
      case MessageType.joined:
        return JoinedMessage.fromJson(json);
      case MessageType.playerList:
        return PlayerListMessage.fromJson(json);
      case MessageType.roundStart:
        return RoundStartMessage.fromJson(json);
      case MessageType.roundProgress:
        return RoundProgressMessage.fromJson(json);
      case MessageType.guess:
        return GuessMessage.fromJson(json);
      case MessageType.guessResult:
        return GuessResultMessage.fromJson(json);
      case MessageType.roundEnd:
        return RoundEndMessage.fromJson(json);
      case MessageType.gameEnd:
        return GameEndMessage.fromJson(json);
      case MessageType.error:
        return ErrorMessage.fromJson(json);
      case MessageType.ping:
        return PingMessage();
      case MessageType.pong:
        return PongMessage();
      default:
        throw FormatException('Unknown message type: ${json['type']}');
    }
  }
}

class PlayerInfo {
  final String id;
  final String name;
  final int score;

  const PlayerInfo({required this.id, required this.name, required this.score});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'score': score};

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        score: json['score'] as int,
      );
}

/// player -> host: request to join a room.
class JoinMessage extends GameMessage {
  final String room;
  final String name;

  JoinMessage({required this.room, required this.name});

  @override
  String get type => MessageType.join;

  @override
  Map<String, dynamic> toJson() => {'type': type, 'room': room, 'name': name};

  factory JoinMessage.fromJson(Map<String, dynamic> json) => JoinMessage(
        room: json['room'] as String,
        name: json['name'] as String,
      );
}

/// host -> player: join acknowledgement.
class JoinedMessage extends GameMessage {
  final String playerId;
  final int roundDuration;

  JoinedMessage({required this.playerId, required this.roundDuration});

  @override
  String get type => MessageType.joined;

  @override
  Map<String, dynamic> toJson() =>
      {'type': type, 'playerId': playerId, 'roundDuration': roundDuration};

  factory JoinedMessage.fromJson(Map<String, dynamic> json) => JoinedMessage(
        playerId: json['playerId'] as String,
        roundDuration: json['roundDuration'] as int,
      );
}

/// host -> all: current player registry.
class PlayerListMessage extends GameMessage {
  final List<PlayerInfo> players;

  PlayerListMessage({required this.players});

  @override
  String get type => MessageType.playerList;

  @override
  Map<String, dynamic> toJson() =>
      {'type': type, 'players': players.map((p) => p.toJson()).toList()};

  factory PlayerListMessage.fromJson(Map<String, dynamic> json) => PlayerListMessage(
        players: (json['players'] as List)
            .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// host -> all: a new round has begun. Never carries the title.
class RoundStartMessage extends GameMessage {
  final int roundIndex;
  final int totalRounds;
  final int startedAtMs;
  final int durationMs;

  RoundStartMessage({
    required this.roundIndex,
    required this.totalRounds,
    required this.startedAtMs,
    required this.durationMs,
  });

  @override
  String get type => MessageType.roundStart;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'roundIndex': roundIndex,
        'totalRounds': totalRounds,
        'startedAtMs': startedAtMs,
        'durationMs': durationMs,
      };

  factory RoundStartMessage.fromJson(Map<String, dynamic> json) => RoundStartMessage(
        roundIndex: json['roundIndex'] as int,
        totalRounds: json['totalRounds'] as int,
        startedAtMs: json['startedAtMs'] as int,
        durationMs: json['durationMs'] as int,
      );
}

/// host -> all: aggregate-only update during a live round — how many players
/// have scored so far. Never carries guess content (see
/// OffTheRecord_HANDOFF.md §8.4: guesses are never broadcast, only this kind
/// of aggregate "social pressure" signal).
class RoundProgressMessage extends GameMessage {
  final int scoredCount;

  RoundProgressMessage({required this.scoredCount});

  @override
  String get type => MessageType.roundProgress;

  @override
  Map<String, dynamic> toJson() => {'type': type, 'scoredCount': scoredCount};

  factory RoundProgressMessage.fromJson(Map<String, dynamic> json) =>
      RoundProgressMessage(scoredCount: json['scoredCount'] as int);
}

/// player -> host: a guess attempt.
class GuessMessage extends GameMessage {
  final String playerId;
  final String text;
  final int clientSentAtMs;

  GuessMessage({required this.playerId, required this.text, required this.clientSentAtMs});

  @override
  String get type => MessageType.guess;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'playerId': playerId,
        'text': text,
        'clientSentAtMs': clientSentAtMs,
      };

  factory GuessMessage.fromJson(Map<String, dynamic> json) => GuessMessage(
        playerId: json['playerId'] as String,
        text: json['text'] as String,
        clientSentAtMs: json['clientSentAtMs'] as int,
      );
}

/// host -> player: outcome of a single guess.
class GuessResultMessage extends GameMessage {
  final bool correct;
  final bool closeEnough;
  final int pointsAwarded;

  GuessResultMessage({
    required this.correct,
    required this.closeEnough,
    required this.pointsAwarded,
  });

  @override
  String get type => MessageType.guessResult;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'correct': correct,
        'closeEnough': closeEnough,
        'pointsAwarded': pointsAwarded,
      };

  factory GuessResultMessage.fromJson(Map<String, dynamic> json) => GuessResultMessage(
        correct: json['correct'] as bool,
        closeEnough: json['closeEnough'] as bool,
        pointsAwarded: json['pointsAwarded'] as int,
      );
}

/// host -> all: round is over, reveal the answer.
class RoundEndMessage extends GameMessage {
  final String title;
  final String artist;
  final List<PlayerInfo> leaderboard;

  RoundEndMessage({required this.title, required this.artist, required this.leaderboard});

  @override
  String get type => MessageType.roundEnd;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'artist': artist,
        'leaderboard': leaderboard.map((p) => p.toJson()).toList(),
      };

  factory RoundEndMessage.fromJson(Map<String, dynamic> json) => RoundEndMessage(
        title: json['title'] as String,
        artist: json['artist'] as String,
        leaderboard: (json['leaderboard'] as List)
            .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// host -> all: game is over.
class GameEndMessage extends GameMessage {
  final List<PlayerInfo> finalLeaderboard;

  GameEndMessage({required this.finalLeaderboard});

  @override
  String get type => MessageType.gameEnd;

  @override
  Map<String, dynamic> toJson() =>
      {'type': type, 'finalLeaderboard': finalLeaderboard.map((p) => p.toJson()).toList()};

  factory GameEndMessage.fromJson(Map<String, dynamic> json) => GameEndMessage(
        finalLeaderboard: (json['finalLeaderboard'] as List)
            .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// Either direction: something went wrong.
class ErrorMessage extends GameMessage {
  final String message;

  ErrorMessage({required this.message});

  @override
  String get type => MessageType.error;

  @override
  Map<String, dynamic> toJson() => {'type': type, 'message': message};

  factory ErrorMessage.fromJson(Map<String, dynamic> json) =>
      ErrorMessage(message: json['message'] as String);
}

/// host -> player keepalive probe.
class PingMessage extends GameMessage {
  @override
  String get type => MessageType.ping;

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// player -> host keepalive reply.
class PongMessage extends GameMessage {
  @override
  String get type => MessageType.pong;

  @override
  Map<String, dynamic> toJson() => {'type': type};
}
