# off_the_record

A local-multiplayer music guessing game for Android. The host runs a lobby and
plays tracks through Spotify; players join over the local network by scanning a
QR code and guess song titles against a timer.

See `OffTheRecord_HANDOFF.md` for the full product and architecture spec.

## Setup

The Spotify client ID is **not** checked in (handoff §9). Before the first run:

```bash
cp dart_defines.example.json dart_defines.json
# edit dart_defines.json and paste your Spotify client ID
```

Then run or build with the defines file:

```bash
flutter run   --dart-define-from-file=dart_defines.json
flutter build apk --dart-define-from-file=dart_defines.json
```

`dart_defines.json` is gitignored. Without it the app still builds, but any
Spotify call throws a `StateError` naming the missing define.

In the Spotify developer dashboard, the same app must register both redirect
URIs — `off-the-record://callback` (Web API PKCE login) and `spotify-sdk://auth`
(App Remote) — plus the Android package name and your keystore's SHA-1.

## Tests

```bash
flutter test
flutter analyze
```
