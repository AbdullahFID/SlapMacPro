import Foundation
import CoreGraphics
import AppKit

/// Shakes all on-screen windows using SkyLight's private SLSSetWindowTransform.
/// Works over fullscreen apps, menubar, dock — everything rattles.
/// The harder the slap, the bigger the shake and longer the duration.
class ScreenShaker {
    private var isShaking = false

    func shake(intensity: Double) {
        guard !isShaking else { return }
        guard let setTransform = SkyLightAPI.setWindowTransform,
              let getTransform = SkyLightAPI.getWindowTransform else {
            log("ScreenShaker: SkyLight API not available")
            return
        }

        isShaking = true
        let conn = SkyLightAPI.connection
        guard conn != 0 else { isShaking = false; return }

        // Get ALL on-screen windows
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else {
            isShaking = false
            return
        }

        // Collect all window IDs (don't filter by layer — shake EVERYTHING)
        let windowIDs = windowInfoList.compactMap { $0[kCGWindowNumber as String] as? UInt32 }

        // Save original transforms
        var originals: [(UInt32, CGAffineTransform)] = []
        for wid in windowIDs {
            var transform = CGAffineTransform.identity
            _ = getTransform(conn, wid, &transform)
            originals.append((wid, transform))
        }

        // Shake parameters scale with intensity
        let maxOffset = 6.0 + intensity * 20.0    // 6-26px displacement
        let shakeCount = 4 + Int(intensity * 6)    // 4-10 oscillations
        let frameDelay = UInt32(20_000)             // 20ms per frame (~50fps)

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            for i in 0..<shakeCount {
                // Damped oscillation: amplitude decays, alternates direction
                let decay = 1.0 - Double(i) / Double(shakeCount)
                let angle = Double(i) * .pi
                let dx = maxOffset * decay * sin(angle)
                let dy = maxOffset * decay * 0.4 * cos(angle * 1.3)

                for (wid, original) in originals {
                    let shaken = original.translatedBy(x: CGFloat(dx), y: CGFloat(dy))
                    _ = setTransform(conn, wid, shaken)
                }

                usleep(frameDelay)
            }

            // Restore all windows
            for (wid, original) in originals {
                _ = setTransform(conn, wid, original)
            }

            self?.isShaking = false
        }
    }
}
