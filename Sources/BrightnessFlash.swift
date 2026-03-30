import Foundation
import CoreGraphics

/// Flashes the hardware display backlight using DisplayServices private API.
/// Works over fullscreen apps, videos, games — everything.
///
/// Strategy: if brightness is already high (>0.8), flash DOWN (dim then restore).
/// If brightness is low, flash UP (spike then restore). Always noticeable.
class BrightnessFlash {
    private var isFlashing = false

    func flash(intensity: Double) {
        guard !isFlashing else { return }
        guard let getBr = DisplayServicesAPI.getBrightness,
              let setBr = DisplayServicesAPI.setBrightness else {
            log("BrightnessFlash: DisplayServices API not available")
            return
        }

        isFlashing = true

        let displayID = CGMainDisplayID()
        var current: Float = 0
        _ = getBr(displayID, &current)

        // Choose flash direction based on current brightness
        let targetBrightness: Float
        if current > 0.8 {
            // Already bright — flash DOWN (dim)
            let drop = Float(0.2 + intensity * 0.4)  // drop 20-60%
            targetBrightness = max(current - drop, 0.1)
        } else {
            // Dark — flash UP (spike)
            let spike = Float(0.1 + intensity * 0.3)
            targetBrightness = min(current + spike, 1.0)
        }

        // Spike to target
        _ = setBr(displayID, targetBrightness)

        // Fade back
        let steps = 15
        let stepDelay: UInt32 = 20_000  // 20ms per step = 300ms total
        let originalBr = current

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            usleep(80_000) // hold the flash for 80ms

            for i in 1...steps {
                let t = Float(i) / Float(steps)
                // Ease-out curve for smooth restore
                let eased = 1.0 - pow(1.0 - t, 2.0)
                let br = targetBrightness + (originalBr - targetBrightness) * eased
                _ = setBr(displayID, br)
                usleep(stepDelay)
            }

            _ = setBr(displayID, originalBr)
            self?.isFlashing = false
        }
    }
}
