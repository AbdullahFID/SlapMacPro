import Foundation
import CoreGraphics
import AppKit

/// Shakes ALL on-screen windows using CGS private API.
/// Uses _CGSDefaultConnection which gives cross-process window access.
/// Every window on screen — Chrome, Dock, menu bar, everything — rattles.
class ScreenShaker {
    private var isShaking = false

    /// Shake intensity multiplier (0.0 to 2.0, default 1.0)
    var intensityMultiplier: Double = 1.0

    func shake(intensity: Double) {
        guard !isShaking else { return }
        isShaking = true

        let conn = CGSDefaultConnection()
        guard conn != 0 else { isShaking = false; return }

        // Get ALL on-screen windows via public CGWindowList API
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else {
            isShaking = false
            return
        }

        // Save every window's current transform
        var originals: [(UInt32, CGAffineTransform)] = []
        for info in windowInfoList {
            guard let wid = info[kCGWindowNumber as String] as? UInt32 else { continue }
            var transform = CGAffineTransform.identity
            _ = CGSGetWindowTransform(conn, wid, &transform)
            originals.append((wid, transform))
        }

        guard !originals.isEmpty else { isShaking = false; return }

        // Scale parameters with intensity + user multiplier
        let scale = intensity * intensityMultiplier
        let maxOffset = 8.0 + scale * 22.0     // 8-30px displacement
        let shakeCount = 5 + Int(scale * 7)     // 5-12 oscillations
        let frameDelay: UInt32 = 22_000          // ~45fps

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            for i in 0..<shakeCount {
                let decay = 1.0 - Double(i) / Double(shakeCount)
                let dx = maxOffset * decay * sin(Double(i) * .pi)
                let dy = maxOffset * decay * 0.35 * cos(Double(i) * .pi * 1.4)

                for (wid, original) in originals {
                    _ = CGSSetWindowTransform(conn, wid, original.translatedBy(x: CGFloat(dx), y: CGFloat(dy)))
                }
                usleep(frameDelay)
            }

            // Restore all
            for (wid, original) in originals {
                _ = CGSSetWindowTransform(conn, wid, original)
            }
            self?.isShaking = false
        }
    }
}
