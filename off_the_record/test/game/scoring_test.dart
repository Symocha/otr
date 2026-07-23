import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/game/scoring.dart';

void main() {
  group('normalizeTitle', () {
    test('lowercases and trims', () {
      expect(normalizeTitle('  Mr. Brightside  '), 'mr brightside');
    });

    test('strips diacritics', () {
      expect(normalizeTitle('Café'), 'cafe');
    });

    test('strips parenthetical suffixes', () {
      expect(normalizeTitle('Thriller (Remastered 2011)'), 'thriller');
      expect(normalizeTitle('Song Title [Live]'), 'song title');
    });

    test('strips trailing " - " suffixes', () {
      expect(normalizeTitle('Hotel California - 2013 Remaster'), 'hotel california');
    });

    test('strips punctuation and collapses whitespace', () {
      expect(normalizeTitle("Don't  Stop   Believin'!"), 'dont stop believin');
    });
  });

  group('levenshtein', () {
    test('identical strings', () {
      expect(levenshtein('abc', 'abc'), 0);
    });

    test('empty strings', () {
      expect(levenshtein('', 'abc'), 3);
      expect(levenshtein('abc', ''), 3);
    });

    test('known distance', () {
      expect(levenshtein('kitten', 'sitting'), 3);
    });
  });

  group('similarity', () {
    test('identical is 1.0', () {
      expect(similarity('same', 'same'), 1.0);
    });

    test('completely different is low', () {
      expect(similarity('abc', 'xyz'), lessThan(0.5));
    });
  });

  group('computeGuessOutcome', () {
    test('exact match is correct with max points near round start', () {
      final outcome = computeGuessOutcome(
        'Mr Brightside',
        'Mr. Brightside',
        timeRemainingMs: 30000,
        roundDurationMs: 30000,
      );
      expect(outcome.correct, isTrue);
      expect(outcome.closeEnough, isTrue);
      expect(outcome.pointsAwarded, 1000);
    });

    test('exact match with no time remaining gives minimum points', () {
      final outcome = computeGuessOutcome(
        'Mr Brightside',
        'Mr. Brightside',
        timeRemainingMs: 0,
        roundDurationMs: 30000,
      );
      expect(outcome.correct, isTrue);
      expect(outcome.pointsAwarded, 500);
    });

    test('exact match at half time remaining gives midpoint points', () {
      final outcome = computeGuessOutcome(
        'Mr Brightside',
        'Mr. Brightside',
        timeRemainingMs: 15000,
        roundDurationMs: 30000,
      );
      expect(outcome.pointsAwarded, 750);
    });

    test('close-but-not-correct guess is flagged closeEnough with no points', () {
      // similarity('abcdefghij', 'abcdefghijklm') = 1 - 3/13 ≈ 0.77, inside [0.70, 0.85).
      final outcome = computeGuessOutcome(
        'abcdefghijklm',
        'abcdefghij',
        timeRemainingMs: 10000,
        roundDurationMs: 30000,
      );
      expect(outcome.correct, isFalse);
      expect(outcome.closeEnough, isTrue);
      expect(outcome.pointsAwarded, 0);
    });

    test('unrelated guess is neither correct nor close', () {
      final outcome = computeGuessOutcome(
        'completely unrelated text',
        'Bohemian Rhapsody',
        timeRemainingMs: 10000,
        roundDurationMs: 30000,
      );
      expect(outcome.correct, isFalse);
      expect(outcome.closeEnough, isFalse);
      expect(outcome.pointsAwarded, 0);
    });
  });
}
