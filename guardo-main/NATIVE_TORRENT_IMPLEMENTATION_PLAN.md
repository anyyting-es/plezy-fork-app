# Native Torrent Implementation Plan (All Platforms)

## Objective
Implement a true native torrent pipeline for:
- Desktop: Windows, Linux, macOS
- Mobile: Android, iOS
- TV: Android TV, tvOS

With one common API used by Flutter and one common playback contract for `media_kit`.

## Recommended Architecture

1. Native core (shared):
- Language: Rust
- Engine: `libtorrent-rasterbar` (via FFI wrapper) OR pure Rust crate if mature enough for streaming use-case
- Exposed API: C ABI + JSON payloads

2. Platform wrappers:
- Android / Android TV: Kotlin + JNI
- iOS / tvOS / macOS: Swift + Objective-C bridge
- Windows / Linux: direct dynamic library loading from Flutter FFI

3. Flutter integration:
- Dart FFI layer (`lib/services/torrent_native_ffi.dart`)
- Keep existing `VideoProvider` contract
- Replace per-platform process spawning with native calls

4. Playback strategy:
- Native core exposes local HTTP stream endpoint (`127.0.0.1:<port>/stream/{id}/{fileIndex}`)
- Flutter `media_kit` keeps using URL playback (minimal UI changes)
- Subtitle behavior stays in mpv path, preserving ASS style

## API Contract (must stay stable)

- `health() -> { status, version, platform }`
- `add_torrent({ magnet|infoHash }) -> TorrentInfo`
- `get_torrent(infoHash) -> TorrentInfo`
- `list_torrents() -> TorrentInfo[]`
- `remove_torrent(infoHash, deleteFiles) -> void`
- `get_stream_url(infoHash, fileIndex) -> string`

`TorrentInfo` fields:
- infoHash, name, size, downloaded, progress, seeders, leechers, files[]

## Execution Phases

### Phase 1 (Android + Android TV first)
- Build Android native module with torrent engine and embedded local HTTP streamer
- Wire MethodChannel for bootstrapping (start/stop/health) + direct URL output
- Keep Flutter provider behavior identical
- Validate on phone + TV emulator

### Phase 2 (Windows/Linux/macOS native)
- Replace Go sidecar with native lib + FFI bridge
- Preserve same HTTP stream endpoint behavior
- Add migration flag to fallback to Go while stabilizing

### Phase 3 (iOS/tvOS)
- Integrate native lib with Apple toolchain
- Background/network constraints review
- Full QA for seek/range requests/subtitles

### Phase 4 (Hardening)
- Persistent session restore
- Piece priority heuristics for fast startup
- Telemetry and crash diagnostics

## Testing Matrix

- Platforms:
  - Windows 11
  - Linux (Ubuntu)
  - macOS
  - Android 10+
  - Android TV 12+
  - iOS 17+
  - tvOS 17+

- Scenarios:
  - Start stream < 10s
  - Seek at 30%, 60%, 90%
  - Multi-release picker
  - ASS subtitles from MKV
  - Network drop/recovery
  - Torrent with single file and multi-file

## Mobile Testing Commands (today)

Android phone:
- `flutter devices`
- `flutter run -d <android-device-id>`

Android TV emulator/device:
- `flutter run -d <android-tv-device-id>`

iOS simulator:
- `flutter run -d ios`

Note: current repo still uses desktop-side Go backend for torrent runtime, so true native torrent behavior is not yet active on mobile/TV.

## Phase 1 Status (Implemented)

Implemented in this repository:
- Android MethodChannel bridge: `anityng/torrent_native`
- Flutter bridge service: `lib/services/torrent_native_bridge.dart`
- `TorrentProvider` strategy switch:
  - Android -> native bridge
  - Desktop -> Go sidecar
  - iOS -> unsupported (next phase)

What Android bridge currently does:
- Calls torrent backend HTTP endpoints natively from Kotlin
- Supports: health, add, get, list, remove, streamUrl
- Uses configurable base URL from dart-define

### Android/TV End-to-End Test (LAN)

1. Start backend on your PC (same Wi-Fi as phone/TV):
- `cd torrent-backend`
- `go build -o torrent-backend.exe .`
- `set TORRENT_PORT=9876`
- `torrent-backend.exe`

2. Get your PC LAN IP (example `192.168.1.50`).

3. Run Flutter on Android/TV with backend URL override:
- `flutter run -d <android-device-id> --dart-define=TORRENT_ANDROID_BASE_URL=http://192.168.1.50:9876`

4. In app:
- Select provider `Torrent`
- Pick episode
- Choose release in torrent source modal

If it fails on mobile:
- Open firewall for TCP 9876 on PC
- Ensure phone/TV and PC are in same network
- Test in mobile browser: `http://192.168.1.50:9876/health`

## Immediate Next Implementation Step

Create Android native torrent bootstrap layer and connect it to `TorrentProvider` behind a platform strategy switch:
- `desktop_go_sidecar`
- `android_native`
- `apple_native`
- `desktop_native`
