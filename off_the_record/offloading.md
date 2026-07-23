# Offloading Notes

## Current State

This workspace contains a Flutter app called `off_the_record`. It is a music/game experience with Spotify auth, a guest login path, a main shell with Play and Playlists tabs, a lobby screen, and a game screen.

The current entry flow is defined in `lib/pages/login_ui.dart`, where the app starts on the login screen, supports guest sign-in, and can connect to Spotify through `SpotApi.login()`.

## What Is Implemented

- Spotify PKCE login via `flutter_web_auth_2`, `flutter_secure_storage`, `http`, and `crypto`.
- Main shell navigation with a profile/logout area and two tabs: Play and Playlists.
- Playlist loading from Spotify user playlists.
- A lobby screen with a room code display, player list, and host-only start button.
- A game screen that shows the target song metadata and a guess input.

## Important Files

- `lib/pages/login_ui.dart` contains the app entry widget, guest login, and Spotify login flow.
- `lib/shell/mainShell.dart` contains the authenticated app shell and tab navigation.
- `lib/api/spotApi.dart` contains the Spotify auth and playlist API calls.
- `lib/pages/play_ui.dart` contains the create/join lobby buttons.
- `lib/pages/lobby_ui.dart` contains the lobby UI and the transition into the game screen.
- `lib/pages/game_ui.dart` contains the guessing UI.
- `lib/pages/playlist_ui.dart` contains the Spotify playlist list view.
- `lib/dto/transfer.dart` currently only stores the global `playerName`.

## Current Gaps

- `lib/pages/game_ui.dart` has an empty send button handler, so guesses are not yet processed.
- `lib/pages/play_ui.dart` and `lib/pages/lobby_ui.dart` still use fixed placeholder room data instead of real multiplayer state.
- `lib/api/spotApi.dart` hardcodes the Spotify client id, which may need to be moved to configuration.
- `test/widget_test.dart` still looks like the default Flutter counter test and does not match this app.

## Best Place To Resume

If work continues, the next practical step is to decide whether the priority is gameplay logic or app cleanup.

Suggested next actions:

1. Wire the game submit flow so guesses are validated and progress updates happen.
2. Replace the placeholder lobby data with actual room and player state.
3. Clean up the test file and add a smoke test for the login or shell flow.

## Quick Resume Summary

The app currently boots into a custom login page, can enter as a guest or through Spotify, then lands in a tabbed shell where Play leads to a placeholder lobby/game path and Playlists shows Spotify playlists.