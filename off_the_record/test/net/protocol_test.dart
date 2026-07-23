import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/net/protocol.dart';

void main() {
  group('GameMessage round-trip', () {
    test('JoinMessage', () {
      final msg = JoinMessage(room: 'K7QF', name: 'Alice');
      final decoded = GameMessage.decode(msg.encode()) as JoinMessage;
      expect(decoded.room, 'K7QF');
      expect(decoded.name, 'Alice');
    });

    test('JoinedMessage', () {
      final msg = JoinedMessage(playerId: 'abc123', roundDuration: 30);
      final decoded = GameMessage.decode(msg.encode()) as JoinedMessage;
      expect(decoded.playerId, 'abc123');
      expect(decoded.roundDuration, 30);
    });

    test('PlayerListMessage', () {
      final msg = PlayerListMessage(players: const [
        PlayerInfo(id: '1', name: 'Alice', score: 500),
        PlayerInfo(id: '2', name: 'Bob', score: 0),
      ]);
      final decoded = GameMessage.decode(msg.encode()) as PlayerListMessage;
      expect(decoded.players.length, 2);
      expect(decoded.players[0].name, 'Alice');
      expect(decoded.players[0].score, 500);
      expect(decoded.players[1].name, 'Bob');
    });

    test('RoundStartMessage', () {
      final msg = RoundStartMessage(
        roundIndex: 2,
        totalRounds: 10,
        startedAtMs: 1000,
        durationMs: 30000,
      );
      final decoded = GameMessage.decode(msg.encode()) as RoundStartMessage;
      expect(decoded.roundIndex, 2);
      expect(decoded.totalRounds, 10);
      expect(decoded.startedAtMs, 1000);
      expect(decoded.durationMs, 30000);
    });

    test('RoundProgressMessage', () {
      final msg = RoundProgressMessage(scoredCount: 3);
      final decoded = GameMessage.decode(msg.encode()) as RoundProgressMessage;
      expect(decoded.scoredCount, 3);
    });

    test('GuessMessage', () {
      final msg = GuessMessage(playerId: 'p1', text: 'Thriller', clientSentAtMs: 12345);
      final decoded = GameMessage.decode(msg.encode()) as GuessMessage;
      expect(decoded.playerId, 'p1');
      expect(decoded.text, 'Thriller');
      expect(decoded.clientSentAtMs, 12345);
    });

    test('GuessResultMessage', () {
      final msg = GuessResultMessage(correct: true, closeEnough: true, pointsAwarded: 750);
      final decoded = GameMessage.decode(msg.encode()) as GuessResultMessage;
      expect(decoded.correct, isTrue);
      expect(decoded.closeEnough, isTrue);
      expect(decoded.pointsAwarded, 750);
    });

    test('RoundEndMessage', () {
      final msg = RoundEndMessage(
        title: 'Thriller',
        artist: 'Michael Jackson',
        leaderboard: const [PlayerInfo(id: '1', name: 'Alice', score: 750)],
      );
      final decoded = GameMessage.decode(msg.encode()) as RoundEndMessage;
      expect(decoded.title, 'Thriller');
      expect(decoded.artist, 'Michael Jackson');
      expect(decoded.leaderboard.single.name, 'Alice');
    });

    test('GameEndMessage', () {
      final msg = GameEndMessage(
        finalLeaderboard: const [PlayerInfo(id: '1', name: 'Alice', score: 4200)],
      );
      final decoded = GameMessage.decode(msg.encode()) as GameEndMessage;
      expect(decoded.finalLeaderboard.single.score, 4200);
    });

    test('ErrorMessage', () {
      final msg = ErrorMessage(message: 'Wrong room code');
      final decoded = GameMessage.decode(msg.encode()) as ErrorMessage;
      expect(decoded.message, 'Wrong room code');
    });

    test('PingMessage and PongMessage', () {
      expect(GameMessage.decode(PingMessage().encode()), isA<PingMessage>());
      expect(GameMessage.decode(PongMessage().encode()), isA<PongMessage>());
    });

    test('unknown type throws', () {
      expect(() => GameMessage.decode('{"type":"nonsense"}'), throwsFormatException);
    });
  });
}
