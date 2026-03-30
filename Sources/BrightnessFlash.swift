import Foundation
import CoreGraphics

/// Flashes the hardware display backlight using DisplayServices private API.
/// Adaptive: if brightness is already high, flashes DOWN (dim). If low, flashes UP.
/// Always noticeable regardless of current brightness level.
class BrightnessFlash {
    private var isFlashing = false

    /// Flash intensity multiplier (0.0 to 2.0, default 1.0)
    var intensityMultiplier: Double = 1.0

    func flash(intensity: Double) {
        guard !isFlashing else { return }
        guard let getBr = DisplayServicesAPI.getBrightness,
              let setBr = DisplayServicesAPI.setBrightness else { return }

        isFlashing = true

        let displayID = CGMainDisplayID()
        var current: Float = 0
        _ = getBr(displayID, &current)

        let scale = Float(intensity * intensityMultiplier)

        // Choose direction: flash DOWN if bright, flash UP if dim
        let target: Float
        if current > 0.5 {
            // Dim flash: drop by 30-70% of current
            target = max(current - (0.3 + scale * 0.4) * current, 0.05)
        } else {
            // Bright flash: spike up
            target = min(current + 0.2 + scale * 0.5, 1.0)
        }

        _ = setBr(displayID, target)

        let originalBr = current
        let steps = 12
        let stepDelay: UInt32 = 22_000 // ~264ms total fade

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            usleep(60_000) // hold flash for 60ms

            for i in 1...steps {
                let t = Float(i) / Float(steps)
                let eased = 1.0 - pow(1.0 - t, 2.5) // ease-out
                let br = target + (originalBr - target) * eased
                _ = setBr(displayID, br)
                usleep(stepDelay)
            }

            _ = setBr(displayID, originalBr)
            self?.isFlashing = false
        }
    }
}
