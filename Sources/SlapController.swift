import Foundation
import Combine

/// Main controller that wires together accelerometer reading,
/// slap detection (5-algorithm voting), and all reaction effects:
/// - Audio playback with escalation
/// - Screen shake (SkyLight private API)
/// - Brightness flash (DisplayServices private API)
/// - Haptic feedback (MultitouchSupport private API)
/// - Screen overlay flash (AppKit)
/// - USB moaner (IOKit)
class SlapController: ObservableObject {
    let audioPlayer = AudioPlayer()
    let usbMonitor = USBMonitor()
    private let accelerometer = AccelerometerReader()
    private var slapDetector: SlapDetector
    private let screenFlash = ScreenFlash()
    let screenShaker = ScreenShaker()
    let brightnessFlash = BrightnessFlash()
    private let hapticFeedback = HapticFeedback()
    private let settings: SettingsStore

    private var lastSlapTime: Date = .distantPast

    init(settings: SettingsStore) {
        self.settings = settings
        self.slapDetector = SlapDetector(config: settings.sensitivity.detectorConfig)

        audioPlayer.loadSounds(for: settings.voicePack)

        // Apply saved intensity multipliers
        screenShaker.intensityMultiplier = settings.shakeIntensity * 2.0
        brightnessFlash.intensityMultiplier = settings.brightnessFlashIntensity * 2.0

        // Wire up slap detection
        slapDetector.onSlap = { [weak self] event in
            self?.handleSlap(event)
        }

        // Wire up accelerometer -> detector
        accelerometer.onSample = { [weak self] x, y, z in
            self?.slapDetector.processSample(x: x, y: y, z: z)
        }

        // Wire up USB events
        usbMonitor.onUSBEvent = { [weak self] in
            guard let self = self, self.settings.usbMoanerEnabled else { return }
            DispatchQueue.main.async {
                self.audioPlayer.playRandom(baseVolume: self.settings.volume)
            }
        }
    }

    func start() {
        let success = accelerometer.start()
        if !success {
            log("WARNING: Could not start accelerometer")
            log("This Mac may not have a compatible sensor (requires M1+ MacBook)")
        }

        if settings.usbMoanerEnabled {
            usbMonitor.start()
        }
    }

    func stop() {
        accelerometer.stop()
        usbMonitor.stop()
    }

    func updateDetectorConfig() {
        slapDetector.updateConfig(settings.sensitivity.detectorConfig)
    }

    private func handleSlap(_ event: SlapEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Enforce user-facing cooldown
            let now = Date()
            guard now.timeIntervalSince(self.lastSlapTime) >= self.settings.cooldownInterval else { return }
            self.lastSlapTime = now

            // 1. Play sound
            self.audioPlayer.play(
                intensity: event.intensity,
                dynamicVolume: self.settings.dynamicVolume,
                baseVolume: self.settings.volume
            )

            // 2. Screen shake (SkyLight private API)
            if self.settings.screenShakeEnabled {
                self.screenShaker.shake(intensity: event.intensity)
            }

            // 3. Brightness flash (DisplayServices private API)
            if self.settings.brightnessFlashEnabled {
                self.brightnessFlash.flash(intensity: event.intensity)
            }

            // 4. Haptic feedback (MultitouchSupport private API)
            if self.settings.hapticFeedbackEnabled {
                self.hapticFeedback.buzz(intensity: event.intensity)
            }

            // 5. Screen overlay flash (AppKit)
            if self.settings.screenFlashEnabled {
                self.screenFlash.flash(intensity: event.intensity)
            }

            // Update count
            self.settings.totalSlapCount += 1
            NotificationCenter.default.post(name: .slapCountChanged, object: nil)

            log("\(event.severity.rawValue) amp=\(String(format: "%.4f", event.magnitude))g " +
                  "vol=\(String(format: "%.0f%%", event.intensity * 100)) " +
                  "detectors=\(event.sources.sorted().joined(separator: "+")) " +
                  "total=\(self.settings.totalSlapCount)")
        }
    }
}
