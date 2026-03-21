# YTBackgroundTweak

A tweak that enables background audio playback for YouTube on iOS 6.

---

## Features

- **Background Playback** — Keep YouTube audio playing when you lock the screen or switch to another app
- **Audio Session Override** — Forces `AVAudioSessionCategoryPlayback` to prevent iOS from killing audio
- **Compatible with both iPhone and iPad**

---

## Requirements

| Item | Requirement |
|---|---|
| Device | iPhone / iPod Touch / iPad (armv7) |
| iOS | 6.0 – 6.1.6 |
| Jailbreak | Any (Cydia / MobileSubstrate required) |
| YouTube | 1.0.0 – 1.3.0 |
| MobileSubstrate | 0.9.6+ |

---

## Installation

### Via Cydia
1. Add the repo : tuanemss.github.io/repo
2. Search for **YTBackground**
3. Install and respring

### Manual (.deb)
```bash
# Copy .deb to device
scp -P 2222 com.tuanem.ytbackground_1.1_iphoneos-arm.deb root@<device-ip>:/tmp/

# Install on device
ssh root@<device-ip>
dpkg -i /tmp/com.tuanem.ytbackground_1.1_iphoneos-arm.deb
killall -9 SpringBoard
```

---

## Building from Source

### Requirements
- macOS with Xcode 13
- [Theos](https://theos.dev)
- iPhoneOS 6.1 SDK (place at `/opt/theos/sdks/iPhoneOS6.1.sdk`)

### Build & Install
```bash
# Clone / download source
cd YTBackgroundTweak

# Build release package
make clean && SYSROOT=/opt/theos/sdks/iPhoneOS6.1.sdk make package FINALPACKAGE=1
```

---

## How It Works

YouTube 1.x on iOS 6 pauses audio when the app enters the background. This tweak intercepts multiple layers of the audio pipeline to prevent this:

1. **`AVPlayer` hooks** — Blocks `pause` and `setRate:0` calls during background transition
2. **`YTPlayer` / `YTPlayerController` hooks** — Blocks `appDidEnterBackground` and `appWillResignActive`
3. **`GIPAudioController` hooks** — Overrides audio session category to `Playback`
4. **`AVAudioSession` hook** — Blocks `setActive:NO` calls
5. **`AudioSessionSetActive` (C-level)** — Hooks the legacy C API via `MSHookFunction`
6. **Poll Timer** — Periodically re-activates audio session after background transition
7. **`NSBundle` hook** — Injects `UIBackgroundModes = [audio]` at runtime for the main bundle only

---

## Changelog

### v1.1
- Fixed keyboard conflict (Vietnamese input now works correctly)
- Fixed `NSBundle` hook scoped to main bundle only
- Improved stability

### v1.0
- Initial release
- Background playback for iPhone / iPod Touch
- iPad support via `YTPlayerScreenController` hooks

---

## Known Issues
- no 

---

## License

```
© 2026 Tuanem. All rights reserved.
```

This tweak is provided as-is for personal use only.
