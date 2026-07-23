import 'dart:math';

import 'package:diacritic/diacritic.dart';

/// Fuzzy title-guessing scoring, run entirely on the host (see
/// OffTheRecord_HANDOFF.md §6). Thresholds and point curve are tunable here.
const double kCloseEnoughThreshold = 0.70;
const double kCorrectThreshold = 0.85;

final _trailingSuffixPattern = RegExp(r'\s+-\s.*$');
final _bracketedSuffixPattern = RegExp(r'[\(\[].*?[\)\]]');
final _punctuationPattern = RegExp(r'[^\w\s]');
final _whitespacePattern = RegExp(r'\s+');

/// Lowercases, strips diacritics, drops "(feat. …)"/"[Live]"/" - Remastered"
/// style suffixes, strips punctuation, and collapses whitespace.
String normalizeTitle(String title) {
  var s = removeDiacritics(title.toLowerCase());
  s = s.replaceAll(_trailingSuffixPattern, '');
  s = s.replaceAll(_bracketedSuffixPattern, '');
  s = s.replaceAll(_punctuationPattern, '');
  s = s.replaceAll(_whitespacePattern, ' ').trim();
  return s;
}

/// Classic Levenshtein edit distance.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  var currentRow = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final deletionCost = previousRow[j + 1] + 1;
      final insertionCost = currentRow[j] + 1;
      final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] = min(deletionCost, min(insertionCost, substitutionCost));
    }
    final swap = previousRow;
    previousRow = currentRow;
    currentRow = swap;
  }

  return previousRow[b.length];
}

/// 1.0 = identical, 0.0 = completely different.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final maxLen = max(a.length, b.length);
  if (maxLen == 0) return 1.0;
  return 1 - levenshtein(a, b) / maxLen;
}

class GuessOutcome {
  final bool correct;
  final bool closeEnough;
  final int pointsAwarded;

  const GuessOutcome({
    required this.correct,
    required this.closeEnough,
    required this.pointsAwarded,
  });
}

/// Scores a single guess against the round's actual title. Points only
/// apply on [correct] (first correct guess per player per round, enforced
/// by the caller) and reward speed: 500-1000 based on time remaining.
GuessOutcome computeGuessOutcome(
  String guess,
  String actualTitle, {
  required int timeRemainingMs,
  required int roundDurationMs,
}) {
  final sim = similarity(normalizeTitle(guess), normalizeTitle(actualTitle));

  if (sim >= kCorrectThreshold) {
    final clampedRemaining = timeRemainingMs.clamp(0, roundDurationMs);
    final points = 500 + (500 * clampedRemaining / roundDurationMs).round();
    return GuessOutcome(correct: true, closeEnough: true, pointsAwarded: points);
  }

  if (sim >= kCloseEnoughThreshold) {
    return const GuessOutcome(correct: false, closeEnough: true, pointsAwarded: 0);
  }

  return const GuessOutcome(correct: false, closeEnough: false, pointsAwarded: 0);
}
