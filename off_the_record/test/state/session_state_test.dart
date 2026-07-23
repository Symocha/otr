import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/state/session_state.dart';

void main() {
  group('SessionState', () {
    test('falls back to Guest before a name is set', () {
      expect(SessionState().displayName, 'Guest');
    });

    test('trims the entered name', () {
      final state = SessionState()..playerName = '  Otran  ';
      expect(state.playerName, 'Otran');
      expect(state.displayName, 'Otran');
    });

    test('a whitespace-only name still reads as Guest', () {
      final state = SessionState()..playerName = '   ';
      expect(state.displayName, 'Guest');
    });

    test('notifies listeners when the name changes', () {
      final state = SessionState();
      var notifications = 0;
      state.addListener(() => notifications++);

      state.playerName = 'Otran';
      expect(notifications, 1);
    });

    test('does not notify when the name is unchanged', () {
      final state = SessionState()..playerName = 'Otran';
      var notifications = 0;
      state.addListener(() => notifications++);

      state.playerName = 'Otran';
      expect(notifications, 0);
    });

    test('clear resets to Guest', () {
      final state = SessionState()..playerName = 'Otran';
      state.clear();
      expect(state.playerName, isEmpty);
      expect(state.displayName, 'Guest');
    });
  });
}
