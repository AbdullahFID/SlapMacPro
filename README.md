# SlapMacPro

Slap your MacBook and it screams back. Open-source, free, no license required.

Built by reverse-engineering [SlapMac](https://slapmac.com/) and studying [taigrr/spank](https://github.com/taigrr/spank), then rewriting from scratch in Swift with extra features using private macOS APIs.

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/AbdullahFID/SlapMacPro.git
cd SlapMacPro

# 2. Build, install, and launch at login (one command)
make install
```

> **Not comfortable with git?** Just click the green **Code** button on GitHub → **Download ZIP**, unzip it, open Terminal, `cd` into the unzipped folder, and run `make install`.

### Pre-built Binary (no Xcode needed)

Download the latest release from the [Releases](../../releases) page. Unzip it and run:

```bash
cd SlapMacPro-release
./install.sh
```

This copies the pre-built binary, sets up launch at login, and starts the app. No Xcode or Swift toolchain required.

That's it. A hand emoji (👋) appears in your menu bar. It starts automatically every time you log in. Slap your MacBook.

If you just want to run it without installing:

```bash
swift build -c release
codesign --force --sign - .build/release/SlapMacClone
.build/release/SlapMacClone
```

## Setup

### Requirements

- macOS 14.6+ (Sonoma or newer)
- Apple Silicon MacBook (M1 / M2 / M3 / M4 / M5)
- Xcode Command Line Tools (`xcode-select --install`)

### Permissions

The app reads your MacBook's built-in accelerometer via IOKit HID. macOS may require:

1. **Input Monitoring** — Go to System Settings > Privacy & Security > Input Monitoring and add your Terminal app (Terminal.app, iTerm2, etc.)
2. If that doesn't work, try running with `sudo` once to bootstrap permissions

### Sound Files

You need `.mp3` or `.wav` sound files in `~/Desktop/slapmac/audio/`. Name them with these prefixes:

| Prefix | Voice Pack |
|--------|-----------|
| `sexy_` | Sexy |
| `punch_` | Combo Hit |
| `male_` | Male |
| `fart_` | Fart |
| `gentleman_` | Gentleman |
| `yamete_` | Yamete |
| `goat_` | Goat |
| `1_` through `9_` | Combo announcer clips |

Example: `sexy_01.mp3`, `punch_05.mp3`, `goat_3.mp3`

You can use any sounds you want — record your own, grab free sound effects, whatever. Just drop them in the folder with the right prefix and restart the app.

**Using SlapMac's sound files:** If you own [SlapMac](https://slapmac.com/) ($7), you can copy their 130+ sound files from the app bundle for personal use:

```bash
mkdir -p ~/Desktop/slapmac/audio
cp /Applications/slapmac.app/Contents/Resources/*.mp3 ~/Desktop/slapmac/audio/
cp /Applications/slapmac.app/Contents/Resources/*.wav ~/Desktop/slapmac/audio/
```

> **Note:** SlapMac's audio files are copyrighted by tonnoz. You may use them locally for personal use if you own the app, but do not redistribute them.

### Install with Launch at Login

```bash
make install
```

This will:
- Build a release binary
- Copy it to `~/Desktop/slapmac/bin/SlapMacPro`
- Create a LaunchAgent (`~/Library/LaunchAgents/com.slapmacpro.plist`) so it starts automatically at login
- Launch it immediately

No `.app` bundle needed — it uses a standard macOS LaunchAgent which works with any binary.

### Managing Launch at Login

```bash
# Disable auto-start (keeps installed, just won't launch at login)
make disable

# Re-enable auto-start
make enable

# Manually stop the running app
launchctl unload ~/Library/LaunchAgents/com.slapmacpro.plist

# Manually start it
launchctl load ~/Library/LaunchAgents/com.slapmacpro.plist
```

### Uninstall

```bash
make uninstall
```

Removes the binary, LaunchAgent, and stops the app completely.

### Other Commands

```bash
# Build debug
swift build

# Build release
make build

# Run without installing (debug, with console output)
swift build && .build/debug/SlapMacClone 2>&1

# View live detection logs
tail -f /tmp/slapmacpro.log
```

## Features

- **5-algorithm slap detection** — High-Pass Filter, STA/LTA (3 timescales), CUSUM, Kurtosis, Peak/MAD. They vote. Democracy, but for physical abuse.
- **7 voice packs** — Sexy, Combo Hit, Male, Fart, Gentleman, Yamete, Goat
- **Dynamic volume** — Logarithmic scaling: gentle taps whisper, hard slaps scream
- **Escalation tracking** — Keep slapping and sounds escalate with a 30s decay half-life
- **Screen Shake** — Captures your screen and shakes it on impact
- **Brightness Flash** — DisplayServices private API dims/flashes the actual hardware backlight
- **Trackpad Haptic Feedback** — Trackpad buzzes on impact
- **Screen Flash** — White overlay flash (AppKit)
- **USB Moaner** — Plug/unplug USB data devices and it reacts
- **Intensity sliders** — Per-effect intensity control from the menu bar
- **Menu bar app** — No dock icon, lives in your menu bar with full controls
- **Launch at login** — Via LaunchAgent, no .app bundle needed
- **Combo system** — Combo Hit pack has an announcer that calls out your combo tier

## Menu Bar Controls

Click the 👋 in your menu bar to access:

```
 Enabled / Disabled
 Voice Pack          → Sexy, Combo Hit, Male, Fart, Gentleman, Yamete, Goat
 Sensitivity         → Extremely Sensitive ... Requires Significant Force
 Cooldown            → None, Fast, Medium, Slow, Very Slow
 Dynamic Volume      → on/off

 Effects
 Screen Flash        → on/off + intensity slider
 Screen Shake        → on/off + intensity slider
 Brightness Flash    → on/off + intensity slider
 Trackpad Haptic     → on/off + intensity slider
 USB Moaner          → on/off

 Volume              → master slider
 Reset Slap Count
 Quit
```

All settings persist automatically between launches.

## Architecture

```
MenuBarExtra (SwiftUI)
  └─ SlapController
       ├─ AccelerometerReader   ← IOKit HID, AppleSPUHIDDevice, ~125Hz
       ├─ SlapDetector          ← 5 algorithms vote on impact
       │    ├─ HighPassFilter   ← strips gravity (1st order IIR)
       │    ├─ STALTADetector   ← seismology algorithm (3 timescales)
       │    ├─ CUSUMDetector    ← cumulative sum change detection
       │    ├─ KurtosisDetector ← 4th statistical moment spike detection
       │    └─ PeakMADDetector  ← median absolute deviation outlier detection
       ├─ AudioPlayer           ← AVFoundation, escalation tracking
       ├─ ScreenShaker          ← CGDisplayCreateImage + overlay shake
       ├─ BrightnessFlash       ← DisplayServices private API
       ├─ HapticFeedback        ← NSHapticFeedbackManager
       ├─ ScreenFlash           ← AppKit NSPanel overlay
       ├─ USBMonitor            ← IOKit notifications + polling
       └─ SettingsStore         ← UserDefaults persistence
```

## How the Detection Works

Your MacBook has a **Bosch BMI286 IMU** (Inertial Measurement Unit) running at 1kHz through Apple's Sensor Processing Unit (`AppleSPUHIDDevice`). The raw reports are 22 bytes with 3-axis acceleration as int32 Q16 fixed-point values.

We decimate to ~125Hz, strip gravity with a high-pass filter, then run the magnitude through five concurrent detectors:

1. **STA/LTA** — Short-Term Average / Long-Term Average ratio at 3 timescales (fast/medium/slow). Classic earthquake detection algorithm borrowed from seismology.
2. **CUSUM** — Cumulative Sum detects sustained shifts in mean acceleration.
3. **Kurtosis** — Measures signal "peakedness". A sharp impact creates a heavy-tailed distribution with high excess kurtosis.
4. **Peak/MAD** — Median Absolute Deviation outlier detection. More robust than standard deviation against baseline contamination.

The detectors **vote**. When enough agree, it classifies the event:

| Detectors | Amplitude | Classification |
|-----------|-----------|---------------|
| 4+ agree  | > 0.05g   | Major Shock   |
| 3+ agree  | > 0.02g   | Medium Shock  |
| Peak fires| > 0.005g  | Micro Shock   |

Volume scales with impact force using a logarithmic curve: `intensity = log(1 + t * 99) / log(100)`

## Private APIs Used

| API | Framework | Purpose |
|-----|-----------|---------|
| `_CGSDefaultConnection` | CoreGraphics | Get WindowServer connection for screen capture |
| `CGSSetWindowTransform` | CoreGraphics | Window affine transforms (screen shake) |
| `DisplayServicesGetBrightness` | DisplayServices | Read hardware backlight level |
| `DisplayServicesSetBrightness` | DisplayServices | Set hardware backlight level |

These are loaded via `@_silgen_name` and `dlopen`/`dlsym`. They work on all Apple Silicon Macs without SIP changes.

## Troubleshooting

**"No accelerometer device found"**
- Make sure you're on an Apple Silicon MacBook (not an iMac/Mac Mini/Mac Pro — they don't have accelerometers)
- Grant Input Monitoring permission to your terminal app in System Settings > Privacy & Security > Input Monitoring
- Try restarting your terminal after granting permissions

**No sound plays**
- Check that sound files exist in `~/Desktop/slapmac/audio/`
- Check that they have the correct prefix (`sexy_`, `male_`, etc.)
- Check your Mac's volume isn't muted

**Screen shake doesn't work**
- Screen shake captures and overlays your screen. If you have very high resolution or multiple displays it might be subtle — crank the intensity slider up in the menu bar

**USB Moaner doesn't detect my device**
- The device must enumerate as a USB data device in macOS. Charge-only cables or devices that don't present USB data won't trigger
- Check with `system_profiler SPUSBDataType` — if your device doesn't show there, SlapMacPro can't see it either

**App doesn't start at login**
- Run `make install` to set up the LaunchAgent
- Check with `launchctl list | grep slapmacpro`

## Credits

- Inspired by [SlapMac](https://slapmac.com/) by tonnoz
- Accelerometer approach from [taigrr/spank](https://github.com/taigrr/spank)
- Detection algorithms based on seismological signal processing (STA/LTA, CUSUM, Kurtosis)

## License

MIT
