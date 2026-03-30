# SlapMacPro

Slap your MacBook and it screams back. Open-source, free, no license required.

Built by reverse-engineering [SlapMac](https://slapmac.com/) and studying [taigrr/spank](https://github.com/taigrr/spank), then rewriting from scratch in Swift with extra features using private macOS APIs.

## Features

- **5-algorithm slap detection** — High-Pass Filter, STA/LTA (3 timescales), CUSUM, Kurtosis, Peak/MAD. They vote. Democracy, but for physical abuse.
- **7 voice packs** — Sexy, Combo Hit, Male, Fart, Gentleman, Yamete, Goat
- **Dynamic volume** — Logarithmic scaling: gentle taps whisper, hard slaps scream
- **Escalation tracking** — Keep slapping and sounds escalate with a 30s decay half-life
- **Screen Shake** — SkyLight private API shakes every window on screen (!!!)
- **Brightness Flash** — DisplayServices private API flashes the actual hardware backlight
- **Haptic Feedback** — Trackpad buzzes on impact
- **Screen Flash** — White overlay flash (AppKit)
- **USB Moaner** — Plug/unplug USB devices and it reacts
- **Menu bar app** — No dock icon, lives in your menu bar with full controls
- **Combo system** — Combo Hit pack has an announcer that calls out your combo tier

## Requirements

- macOS 14.6+ (Sonoma)
- Apple Silicon MacBook (M1/M2/M3/M4/M5) — needs the built-in BMI286 accelerometer
- Sound files in `~/Desktop/slapmac/audio/` (bring your own .mp3/.wav files)

## Build & Run

```bash
# Build and run (debug)
swift build && .build/debug/SlapMacClone

# Build release
make build

# Run release
make run

# Install to /usr/local/bin
sudo make install
```

## Architecture

```
MenuBarExtra (SwiftUI)
  └─ SlapController
       ├─ AccelerometerReader   ← IOKit HID, AppleSPUHIDDevice, ~125Hz
       ├─ SlapDetector          ← 5 algorithms vote on impact
       │    ├─ HighPassFilter   ← strips gravity
       │    ├─ STALTADetector   ← seismology algorithm (3 timescales)
       │    ├─ CUSUMDetector    ← cumulative sum change detection
       │    ├─ KurtosisDetector ← 4th statistical moment
       │    └─ PeakMADDetector  ← median absolute deviation outlier detection
       ├─ AudioPlayer           ← AVFoundation, escalation tracking
       ├─ ScreenShaker          ← SkyLight SLSSetWindowTransform (private API)
       ├─ BrightnessFlash       ← DisplayServices SetBrightness (private API)
       ├─ HapticFeedback        ← NSHapticFeedbackManager
       ├─ ScreenFlash           ← AppKit NSPanel overlay
       ├─ USBMonitor            ← IOKit USB notifications
       └─ SettingsStore         ← UserDefaults
```

## How the Detection Works

Your MacBook has a **Bosch BMI286 IMU** running at 1kHz through Apple's Sensor Processing Unit. We decimate to 125Hz, strip gravity with a high-pass filter, then run the magnitude through five concurrent detectors:

1. **STA/LTA** — Short-Term Average / Long-Term Average ratio at 3 timescales. Classic earthquake detection algorithm.
2. **CUSUM** — Cumulative Sum detects sustained shifts in mean acceleration.
3. **Kurtosis** — Measures signal "peakedness". Sharp impacts have excess kurtosis >> 0.
4. **Peak/MAD** — Median Absolute Deviation outlier detection. More robust than standard deviation.

When enough detectors agree, it classifies the event:
- **4+ detectors + amp > 0.05g** → Major Shock
- **3+ detectors + amp > 0.02g** → Medium Shock
- **Peak triggered + amp > 0.005g** → Micro Shock

## Private APIs Used

| API | Framework | What it does |
|-----|-----------|-------------|
| `SLSMainConnectionID` | SkyLight | Get WindowServer connection |
| `SLSSetWindowTransform` | SkyLight | Apply affine transform to any window |
| `SLSGetWindowTransform` | SkyLight | Read current window transform |
| `DisplayServicesGetBrightness` | DisplayServices | Read hardware backlight level |
| `DisplayServicesSetBrightness` | DisplayServices | Set hardware backlight level |

## Sound Files

Place `.mp3` or `.wav` files in `~/Desktop/slapmac/audio/` with these prefixes:

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

## Credits

- Inspired by [SlapMac](https://slapmac.com/) by tonnoz
- Accelerometer approach from [taigrr/spank](https://github.com/taigrr/spank)
- Detection algorithms based on seismological signal processing literature

## License

MIT
