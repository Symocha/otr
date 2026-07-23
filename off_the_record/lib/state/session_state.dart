import 'package:flutter/foundation.dart';

/// App-wide instance. Matches the singleton-`ChangeNotifier` pattern already
/// used by `playlistRepository` and `hotspotSettings`.
final sessionState = SessionState();

/// Who the user is for this run of the app (handoff §9).
///
/// Replaces the bare `String playerName` global that `lib/dto/transfer.dart`
/// used to hold: same single source of truth, but observable, so screens
/// showing the name refresh instead of relying on a rebuild happening anyway.
class SessionState extends ChangeNotifier {
  String _playerName = '';

  /// Raw value as typed; may be empty before login completes.
  String get playerName => _playerName;

  /// What to show and what to send to a host on join.
  String get displayName => _playerName.isNotEmpty ? _playerName : 'Guest';

  set playerName(String value) {
    final trimmed = value.trim();
    if (trimmed == _playerName) return;
    _playerName = trimmed;
    notifyListeners();
  }

  void clear() => playerName = '';
}
