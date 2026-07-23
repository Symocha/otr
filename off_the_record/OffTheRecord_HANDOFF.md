# OffTheRecord — Agent Handoff Document

> Handoff for the next coding agent. This document consolidates the current codebase state, all product decisions made with the owner, the technical architecture to follow, and the prioritized roadmap. Read fully before writing code.

---

## 1. Project Overview

**OffTheRecord** is a Flutter (Dart) Android app: a local-multiplayer music trivia/guessing game built around Spotify playlists.

**Core loop:** A host creates a lobby on their phone. Music plays through the host's device via the Spotify App Remote. Players join the lobby by scanning a QR code and type guesses for the song title. The host device scores guesses locally (fuzzy title match + time bonus) and broadcasts a leaderboard.

**Important context:**

- This is **strictly for personal use**. The owner is aware Spotify's developer terms prohibit games built on their API; do not publish, distribute, or add monetization. Keep the Spotify client ID out of source control regardless (see §9).
- **No backend server.** All multiplayer runs peer-to-peer on the local Wi-Fi network with the host device acting as the server (see §4).
- **v1 target: Android only.** Do not spend effort on iOS permissions, desktop, or web.

---

## 2. Locked Product Decisions

These were decided explicitly with the owner. Do not re-litigate them without asking.

| Topic | Decision |
|---|---|
| Platform (v1) | Android only |
| Multiplayer transport | WebSocket server hosted **inside the host's app** over local Wi-Fi; QR code carries the connection info |
| Host role | Host is a **dedicated DJ** — they run playback and scoring but do **not** guess |
| Guessing | **Unlimited guesses** per player per song, until correct or round timeout |
| Round end | **Fixed timer per song** (default 30 s, make it configurable in lobby settings) |
| Scoring | Fuzzy closeness to the title; points only awarded if the guess is close enough; faster correct answers score more |
| Playlist collaboration | Use **Spotify's native collaborative playlists** via the Web API — available only to Spotify-authenticated users. Local-save users get personal (non-collaborative) playlists only |
| Playlist storage | Locally on device. Store **track/playlist IDs and metadata only — never audio files** |
| Premade playlists | App ships with premade playlists (hardcoded track ID lists) and/or fetches popular public Spotify playlists |
| Auth | Two paths: (a) Spotify login (existing PKCE flow), (b) **local save** where the user only enters a display name |
| Playback | Spotify App Remote on the **host device only**. Requires the host to have the Spotify app installed and a **Premium** account. Guests never need Spotify |

---

## 3. Current Codebase State

The repo already contains a working skeleton (Flutter app `off_the_record`):

**Implemented:**
- Spotify PKCE login (`flutter_web_auth_2`, `flutter_secure_storage`, `http`, `crypto`) in `lib/api/spotApi.dart`
- Entry/login flow with guest sign-in in `lib/pages/login_ui.dart`
- Authenticated shell with Play and Playlists tabs in `lib/shell/mainShell.dart`
- Spotify playlist fetching + list view (`lib/pages/playlist_ui.dart`)
- Lobby screen with room code display, player list, host-only start button (`lib/pages/lobby_ui.dart`)
- Game screen showing target song metadata and a guess input (`lib/pages/game_ui.dart`)
- `lib/dto/transfer.dart` — currently only holds a global `playerName`

**Known gaps / debt:**
- `game_ui.dart`: guess send button handler is **empty** — guesses go nowhere
- `play_ui.dart` and `lobby_ui.dart`: hardcoded placeholder room/player data, no real multiplayer state
- `spotApi.dart`: Spotify client ID is **hardcoded** — move to config (see §9)
- `test/widget_test.dart`: still the default Flutter counter test — replace

---

## 4. Networking Architecture (Priority 1)

**Pattern: host-as-server over local Wi-Fi.** No external server, no signaling, no WebRTC, no Bluetooth, no Wi-Fi Direct. Everyone must be on the same Wi-Fi network — acceptable for a couch/party game.

### Host side
1. On lobby creation, start a WebSocket server in-app using `dart:io` `HttpServer` upgraded via `web_socket_channel` (`WebSocketTransformer`). Bind to `0.0.0.0` on an ephemeral or fixed port (e.g. 4545, fall back to next free port).
2. Get the device's LAN IP with `network_info_plus` (`getWifiIP()`).
3. Generate a short room code (4–6 alphanumeric) purely as a human-readable label / join guard.
4. Render a QR code (`qr_flutter`) encoding a JSON payload:
   ```json
   {"v":1,"ip":"192.168.1.42","port":4545,"room":"K7QF"}
   ```
5. Host holds the authoritative game state: player registry, current round, timers, scores.

### Player side
1. Scan QR with `mobile_scanner`, parse payload, open `WebSocketChannel.connect('ws://ip:port')`.
2. Send a `join` message with room code + display name; wait for `joined` ack.
3. All gameplay flows over this single socket.

### Message protocol (JSON, `type` field discriminates)

Define these as sealed Dart classes with `toJson`/`fromJson` in a shared `lib/net/protocol.dart`:

- `join` (player→host): `{type, room, name}`
- `joined` (host→player): `{type, playerId, roundDuration}`
- `player_list` (host→all): `{type, players:[{id,name,score}]}`
- `round_start` (host→all): `{type, roundIndex, totalRounds, startedAtMs, durationMs}` — **do not send the title**; optionally send artist/album art if you want hint features later
- `guess` (player→host): `{type, playerId, text, clientSentAtMs}`
- `guess_result` (host→player): `{type, correct, closeEnough, pointsAwarded}`
- `round_end` (host→all): `{type, title, artist, leaderboard:[...]}`
- `game_end` (host→all): `{type, finalLeaderboard}`
- `error`, `ping`/`pong` (keepalive every ~10 s; drop dead sockets and broadcast updated `player_list`)

**Timing:** score on **host receive time** relative to `round_start` broadcast time. Do not trust client timestamps for scoring (clock skew); `clientSentAtMs` is informational only.

**Reconnects:** keep it simple — if a player's socket drops, keep their score under their `playerId` for the game's duration and let them rejoin with the same name to reclaim it.

**Android specifics:** add `INTERNET` permission; keep the screen awake on host during a game (`wakelock_plus`); consider a foreground service only if backgrounding kills the server (test first — likely unnecessary for v1 since the host keeps the app open as the DJ console).

### 4b. No Wi-Fi available — hotspot mode

Expect this to be the common case (parties, cars, outdoors). **The host enables their Android hotspot and players join it.** This requires *no changes to the transport* — same WebSocket server, same protocol, same QR — because the game only needs a shared local network, not internet.

**Audio is the real constraint, not messaging.** Game messages are pure LAN traffic and need zero internet. The **Spotify App Remote does need internet to stream**, unless the host has downloaded the playlist via Premium offline mode. So:

- Host tethers from cellular → hotspot has internet → everything works normally. This is the expected path.
- Host has no cellular data → game only works with **pre-downloaded** Spotify playlists.
- **Recommended:** add a pre-game readiness check on the host ("Spotify connected / offline playlist available?") so a lobby doesn't start and then stall on the first song.

**Critical implementation gotcha — host IP discovery.** When the host device *is* the access point, `network_info_plus.getWifiIP()` returns `null` or a stale value, because it reads the Wi-Fi **client** interface, which is down while tethering. Do not rely on it. Instead:

```dart
// Works both as Wi-Fi client and as hotspot AP
Future<String?> resolveLocalIp() async {
  final ifaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  // Prefer AP interfaces (OEM-dependent: ap0, swlan0, wlan1), then wlan0
  const priority = ['ap0', 'swlan0', 'wlan1', 'wlan0'];
  for (final name in priority) {
    final match = ifaces.where((i) => i.name.startsWith(name));
    if (match.isNotEmpty) return match.first.addresses.first.address;
  }
  return ifaces.isNotEmpty ? ifaces.first.addresses.first.address : null;
}
```

Android hotspot hosts are typically `192.168.43.1`, but **do not hardcode it** — OEMs vary. Bind the server to `0.0.0.0` so it listens on whichever interface comes up.

**Join-flow chicken-and-egg.** Players must join the hotspot *before* they can scan the game QR. Lobby screen should show two steps:

1. **Wi-Fi QR** in the standard format `WIFI:S:<ssid>;T:WPA;P:<password>;;` — the stock Android camera parses this and joins the network natively.
2. **Game QR** (the `{ip, port, room}` payload from §4).

For v1, the host types their hotspot SSID/password once and the app persists it (modern Android blocks apps from reading hotspot credentials). A later polish pass can use Android's **`LocalOnlyHotspot`** API (API 26+), which lets the app start an AP *and read back the generated SSID/passphrase programmatically* — ideal here, but it needs a Kotlin platform channel, location permission, and it drops the host's own Wi-Fi connection. Not v1.

**Also warn players:** Android may show "this network has no internet" and offer to switch to mobile data. Local-subnet traffic still routes over Wi-Fi, but if the OS auto-disconnects, the socket dies. Add a short in-app hint telling players to tap "stay connected."

**Fallback if hotspot UX proves painful:** Google's **Nearby Connections** (`nearby_connections` package, `P2P_STAR` strategy) needs no network setup at all — it auto-negotiates Bluetooth/BLE/Wi-Fi Direct under the hood, and its star topology matches the host/players model exactly. It was ruled out initially for being Android-only, which no longer matters given the v1 target. Costs: requires Google Play Services and location permissions, doesn't fit the QR join flow (uses discovery + endpoint names), and is an entirely separate code path from the WebSocket server. **Do not build both.** Ship WebSocket + hotspot first, and only evaluate this if real-device testing shows hotspot joining is too fiddly.

---

## 5. Playlist Storage & Premades (Priority 2)

- Store playlists locally with **`hive_ce`** (simple, no schema migrations for v1). Alternative: `sqflite` if you prefer SQL. Model:
  ```dart
  class LocalPlaylist { String id; String name; String? spotifyPlaylistId; List<LocalTrack> tracks; bool isPremade; }
  class LocalTrack { String spotifyTrackId; String title; String artist; String? albumArtUrl; int? durationMs; }
  ```
- **Never store audio.** Only Spotify track IDs + display metadata. Playback resolves IDs through the Spotify App Remote at game time.
- **Premades:** ship 3–5 JSON asset files (e.g. "2000s Hits", "Rock Classics", "Rap FR") bundled in `assets/premade/`, imported into Hive on first launch. Optionally, for Spotify-authed users, add a "Popular on Spotify" fetch (featured/category playlists endpoint) that imports a snapshot locally.
- **Editing:** local-save users can create/edit local playlists (search requires Spotify auth, so local users can only reorder/remove from premades or imported lists — flag this limitation in UI). Spotify users can search tracks (Web API `/v1/search`) and add by ID.
- **Collaboration:** for Spotify users only, create/flag playlists as collaborative through the Spotify Web API and let collaborators edit in Spotify itself; the app re-syncs the playlist (pull-to-refresh) before a game. Do **not** build custom collab sync — Spotify handles it.

---

## 6. Scoring Logic (Priority 3)

Runs entirely on the host. Suggested spec (tunable constants in one config file):

1. **Normalize** both guess and actual title:
   - lowercase, trim, collapse whitespace
   - strip diacritics
   - remove parenthetical/bracket suffixes: `(feat. …)`, `(Remastered 2011)`, `[Live]`, `- Radio Edit`, `- Remaster`, etc. (regex on ` - .*$` and `[\(\[].*?[\)\]]`)
   - strip punctuation
2. **Similarity:** `sim = 1 - levenshtein(a, b) / max(a.length, b.length)`
3. **Threshold:** accept if `sim ≥ 0.85` (start there; expose as a constant). Below threshold → `closeEnough: false`, player may keep guessing (unlimited attempts).
4. **Points** (first correct guess per player per round only):
   `points = 500 + round(500 * timeRemainingMs / roundDurationMs)` → range 500–1000, rewarding speed.
5. Optional nicety: if `0.70 ≤ sim < 0.85`, reply with a "so close!" flag so the UI can nudge the player.
6. On timeout, broadcast `round_end` with the reveal and updated leaderboard.

Use the `diacritic` package for accent stripping; write the Levenshtein by hand or use `string_similarity` (verify current pub.dev health before adding).

---

## 7. Spotify Remote Playback (Priority 4)

- Use the **`spotify_sdk`** package (wraps Spotify App Remote + auth) on the **host only**.
- Requirements: Spotify app installed on host device, host has **Premium**, app's redirect URI + package signature registered in the Spotify developer dashboard.
- Per round: `play('spotify:track:<id>')`, optionally seek to a random offset for extra difficulty (config flag, default off), `pause()` on round end.
- Guests hear audio acoustically from the host device/speaker — **never** stream audio to guests.
- Handle App Remote disconnects gracefully: pause the game, show a "reconnect Spotify" banner on host.

---

## 8. Visual Design

**Direction: neon party.** Dark, saturated, high-energy — built for dim rooms and chaotic group play. Not a Spotify clone, not a minimal utility app.

### 8.1 Two UIs, opposite goals

This is the single most important visual principle. OffTheRecord is not one interface:

- **Player screens** are fast, one-handed, thumb-driven, used under time pressure with the keyboard open. Compact, dense, everything reachable.
- **Host screens** are a stationary DJ console — the phone is propped up, viewed at arm's length or across a room, and the keyboard never opens. Large type, big touch targets, glanceable.

Never reuse a player layout on the host or vice versa. They share only the palette.

**Screen inventory**, tagged by which UI it belongs to:

| Screen | UI |
|---|---|
| Login (Spotify or name only) | Shared |
| Main shell — play + playlists tabs | Shared |
| Lobby — QR codes, settings, start | Host |
| Join — scan QR, then waiting room | Player |
| DJ console — timer, guess feed, skip | Host |
| Guess screen — timer, input, feedback | Player |
| Round reveal — title + art revealed | Both, separate layouts |
| Final scores | Both, separate layouts |
| Playlist list / detail / track search | Shared |

### 8.2 Palette

Define these once as a `ThemeExtension` or a constants file — do not scatter hex literals.

| Role | Hex | Use |
|---|---|---|
| Background | `#0B0710` | App canvas |
| Surface raised | `#1A1424` | Cards, input fields, list rows |
| Surface alt | `#251C33` | Keyboard keys, inactive fills |
| Track / inactive | `#241A2E` | Timer bar background |
| Border dim | `#3D2B4F` | Hairlines, inactive borders |
| Divider | `#2A2035` | Section separators |
| Text primary | `#EDE9F5` | Titles, input text |
| Text secondary | `#B8AEC9` | Body, secondary labels |
| Text muted | `#7E7590` | Metadata, hints |
| Text disabled | `#6E6580` | Rejected guesses, dead state |
| **Magenta** | `#FF2D95` | Time, urgency, primary action |
| On magenta | `#3D0022` | Text/icons on magenta fills |
| **Cyan** | `#00E5FF` | Scored / success / points |
| On cyan | `#04323A` | Text/icons on cyan fills |
| Cyan tint bg | `#0C2B31` | Correct-guess row background |
| Cyan tint text | `#8FD9E6` | Text on cyan tint |
| **Amber** | `#FFB020` | Near-miss, social pressure |
| Amber tint bg | `#2E2110` | Near-miss row background |
| Amber tint text | `#F5D9A8` | Text on amber tint |
| Amber tint border | `#6B4A12` | Near-miss chip border |
| Purple | `#7B2E8E` | Waveform mid-tones, art placeholder |
| Danger red | `#FF2D2D` | Timer under 5 seconds only |

### 8.3 Color roles are fixed

A saturated palette turns to mush without discipline. **Three accents, each with exactly one meaning, everywhere in the app:**

- **Magenta** = time and urgency. Also the primary action color (this is why `skip` is magenta and `pause` is not).
- **Cyan** = scored / success / points. Correct guesses, point awards, your score.
- **Amber** = near-miss and social pressure. The 0.70–0.85 similarity band, the "others already scored" ticker.

Nothing else gets a color. The **only** exception: the timer bar flips magenta → `#FF2D2D` below 5 seconds.

**Do not build the app around Spotify green.** Beyond it being their trademark, visual distance from Spotify is desirable here. Spotify green appears on exactly one element: the "connect Spotify" button, styled per their brand guidelines.

### 8.4 Spoiler rules (non-negotiable)

- **Album art and title never appear on a player device during a round.** The cover gives the song away instantly. The player's guess screen has a deliberate hole where art would go.
- **Guesses are never broadcast to other players.** Only aggregate signals ("2 players already nailed it") — this manufactures urgency without leaking the answer.
- **The host device is the answer key.** The host sees art, title, and artist — they need it to make skip decisions and they don't guess. Show a persistent "hidden from players" affordance as a reminder not to show the screen around. Carry the same warning into the lobby. If this proves a problem in playtesting, fall back to tap-to-reveal on the title.

### 8.5 Layout constraints

**Player guess screen — the hardest layout in the app.** With the Android keyboard open you have roughly 40% of the viewport. Timer, text field, and last-guess feedback must all live above that fold permanently. This is why the timer is a **thin horizontal bar, not a circular dial** — the dial the neon direction naturally suggests does not fit. When the keyboard closes, the freed space fills with the live leaderboard.

**Host console.** No keyboard ever, so the timer becomes a large numeral. The live guess feed is the host's entertainment and the reason being DJ is worth doing. Because guesses are unlimited, **cap the feed** — newest at top, ~6 visible, older entries dropped from the widget tree rather than kept offscreen. The host device is simultaneously running the WebSocket server, the round timer, and Spotify playback; the feed must not be what makes it stutter.

**The round reveal is the payoff.** Everything hidden during the round lands at once — art slams in, title resolves, scores animate. Design this transition early; the rest of the game screen follows from it.

### 8.6 Flutter implementation notes

- **Glow is real glow.** Use `BoxShadow` with a large `blurRadius` and low opacity in the accent color behind timer bars, the send button, and correct-guess rows. Flat saturated color alone reads as cheap.
- **The player-side waveform is decorative and must be.** The player's phone is not playing audio — sound comes from the host's speaker — so there is no signal to analyze. Drive it from the round timer with a looping animation. Do not attempt audio analysis on the player device; it cannot work.
- Respect `MediaQuery.viewInsets.bottom` for the keyboard fold rather than assuming a fixed height.
- Keep animations under ~2s loops and honor reduced-motion settings.
- All screens are dark-only. There is no light theme; do not build one.

---

## 9. Config & Hygiene

- Move the Spotify client ID out of `spotApi.dart` into `--dart-define` / an untracked `env.dart` (gitignored) with a checked-in `env.example.dart`.
- Replace `test/widget_test.dart` with at least: a smoke test of the login screen, a unit test suite for the scoring normalizer/similarity (this is the highest-value test target — pure functions, easy wins), and a protocol serialization round-trip test.
- `lib/dto/transfer.dart` (global `playerName`) should evolve into proper state management. Suggest `provider` or `riverpod` for: auth/session state, lobby/game state (host + player variants), playlist repository.

---

## 10. Prioritized Roadmap (owner-ranked)

1. **Lobby networking** — host WebSocket server, QR join flow, protocol, real player list in `lobby_ui.dart` (replaces placeholder data). *Definition of done: two physical Android devices on the same Wi-Fi can create/join a lobby and exchange ping messages, player list updates live.*
2. **Playlist storage & premades** — Hive models, bundled premade assets, local playlist CRUD, Spotify playlist import for authed users.
3. **Guess scoring** — wire the empty send handler in `game_ui.dart` to the socket, implement normalizer + Levenshtein + time bonus on host, live leaderboard, round timer, `round_end` reveal.
4. **Spotify remote playback** — `spotify_sdk` integration on host, play/pause per round, disconnect handling.
5. Cleanup: config extraction, tests, state management refactor (can be interleaved).

Suggested new modules: `lib/net/` (server, client, protocol), `lib/game/` (game state machine, scoring), `lib/storage/` (Hive repos, premade importer).

---

## 11. Open Questions (ask the owner before assuming)

- Exact round count per game and whether the host picks it per lobby (suggest: configurable, default 10 songs).
- Whether wrong-guess feedback shows similarity hints or just "not it".
- Whether "Popular on Spotify" premade fetching is v1 or later (safe default: bundled JSON premades only for v1).
- Random-seek playback difficulty option: v1 or later.
