# ResumeOffload — OffTheRecord Session Summary

This supersedes `offloading.md` (repo root), which reflects the state *before* this session and is now stale.

## Current State

All four roadmap priorities from `OffTheRecord_HANDOFF.md` are implemented and committed, plus a full neon visual pass. Current branch: **`playback`** (tip of the work), branched off `ScoreLogic` ← `playlists` ← `playPage` ← `main`.

Commit history for this session, oldest first:

| Commit | Branch | What |
|---|---|---|
| `eca832f` | `playPage` | Priority 1 — Lobby networking (WebSocket host/client, QR join, protocol) |
| `73ba8e9` | `playlists` | Priority 2 — Playlist storage (Hive, premades, local CRUD, Spotify import) |
| `7cbd0d4` | `ScoreLogic` | Priority 3 — Guess scoring (fuzzy match, round state machine, DJ console + guess screen split) |
| `ec2dc33` | `playback` | Priority 4 — Spotify Remote Playback (spotify_sdk, vendored App Remote AAR, pause/resume on disconnect) |
| `4cba28a` | `playback` | Reworked host console + player guess screen to match two owner-provided neon HTML mockups; added `round_progress` protocol message |
| `a792944` | `playback` | Extended the neon palette to Login, Play, Lobby, Join, and MainShell chrome |

None of this is merged to `main` yet — it all lives on `playback`.

## What Is Implemented

- **Networking** (`lib/net/`): `protocol.dart` (full message set incl. `round_progress`), `host_server.dart` (WebSocket server, keepalive, reconnect-by-name), `game_client.dart`, `network_utils.dart` (hotspot-aware IP resolution).
- **Storage** (`lib/storage/`): `models.dart` (`LocalPlaylist`/`LocalTrack`), `playlist_repository.dart` (Hive-backed CRUD, premade import, Spotify import/resync). Premades in `assets/premade/*.json` — track IDs individually verified against Spotify's oEmbed endpoint.
- **Game logic** (`lib/game/`): `scoring.dart` (normalize + Levenshtein + threshold/point curve), `game_session.dart` (host-only round state machine, pause/resume, guess feed, round_progress ticker).
- **Audio** (`lib/audio/spotify_playback.dart`): host-only `spotify_sdk` wrapper, try/catch-as-disconnect-signal pattern.
- **Theme** (`lib/theme/`): `palette.dart` (`OtrColors`, now applied app-wide except Playlists), `otr_logo.dart` (shared "T R" mark).
- **Screens**: `login_ui.dart`, `play_ui.dart`, `join_ui.dart`, `lobby_ui.dart`, `host_console_ui.dart` (DJ console), `player_game_ui.dart` (guess screen) — all neon-themed and wired to real state. `playlist_ui.dart` / `playlist_detail_ui.dart` still use the original teal/dark-blue look (explicitly out of scope so far).
- Tests: `test/net/`, `test/storage/`, `test/game/` (incl. `game_session_test.dart` for pause/resume timing), `test/widget_test.dart`. 39 tests, all passing as of `a792944`.

## Known Gaps / Deferred Scope

- **Priority 2 extras (deferred by owner decision)**: Spotify track search-and-add for building custom playlists, and collaborative-playlist creation via the Spotify Web API. Storage/CRUD/import foundation is done; these are additive.
- **Roadmap cleanup phase (§9, not started)**: Spotify client ID is still hardcoded in `lib/api/spotApi.dart` (needs `--dart-define`/gitignored `env.dart`); no `provider`/`riverpod` state-management refactor has been done (deliberately kept minimal — `ChangeNotifier` + listeners throughout).
- **Playlists tab**: still on the original palette; user has not asked for this yet.
- **Owner-only follow-ups I cannot do myself**:
  - Spotify Developer Dashboard: add `spotify-sdk://auth` as a redirect URI (alongside the existing `off-the-record://callback`) on the same app as `SpotApi.clientId`, and register the package name (`com.example.off_the_record`, still template default) + your keystore's SHA-1.
  - All on-device verification (two-device lobby join over Wi-Fi/hotspot, actual Spotify App Remote playback with Premium) — I have no physical Android device.
- **Vendored binary**: `android/spotify-app-remote/spotify-app-remote-release-0.8.0.aar` is committed (downloaded from Spotify's official `spotify/android-sdk` GitHub releases) because `spotify_sdk` 3.0.2 needs it locally and the auto-resolving 4.0.0-dev release needs a newer Dart SDK than this toolchain has (`3.12.0-249.0.dev`, a pre-release build that doesn't satisfy 4.0.0-dev's `>=3.12.0` constraint).

## Best Place to Resume

The roadmap's four priorities are functionally done. Next practical steps, roughly in order of likely value:
1. On-device pass (owner): register the Spotify dashboard items above, then run a real two-device game end-to-end. This will surface whatever this session's automated verification (analyze/test/build only) couldn't catch.
2. If continuing feature work: track search-and-add or collaborative playlists (Priority 2 extras), or the config-hygiene/state-management cleanup phase.
3. If continuing visual work: bring the Playlists tab in line with the neon theme, or extend the mockup-matching treatment to the round-reveal/final-score screens (neither had a reference mockup — current design there is my own extrapolation from the palette, not a followed spec).
4. Merge `playback` back toward `main` whenever the owner is satisfied with on-device testing — nothing here has been merged/pushed.

## Quick Resume Summary

OffTheRecord is a fully wired local-multiplayer Spotify trivia game: host creates a lobby (WebSocket + QR), players join and guess song titles, the host scores fuzzy matches and plays/pauses the actual track via Spotify App Remote, and everything is styled in a neon dark theme end-to-end except the Playlists tab. All four handoff-doc priorities are done and committed on the `playback` branch (unmerged). What's left is owner-side device/dashboard verification, and optional follow-on work (playlist search/collab, config cleanup, Playlists tab restyle).
