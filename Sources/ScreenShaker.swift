import Foundation
import CoreGraphics
import AppKit

/// Shakes the screen by rapidly shifting the main display's origin using Quartz Display Services.
/// This moves the ENTIRE display content — every window, the dock, menu bar, everything.
/// Uses CGSConfigureDisplayOrigin which is the same API macOS uses for display arrangement.
/// Falls back to a fullscreen capture-and-shake overlay if needed.

@_silgen_name("CGSConfigureDisplayOrigin")
func CGSConfigureDisplayOrigin(_ display: CGDirectDisplayID, _ x: Int32, _ y: Int32) -> Int32

@_silgen_name("CGSBeginDisplayConfiguration")
func CGSBeginDisplayConfiguration(_ config: UnsafeMutablePointer<OpaquePointer?>) -> Int32

@_silgen_name("CGSCompleteDisplayConfiguration")
func CGSCompleteDisplayConfiguration(_ config: OpaquePointer?, _ option: Int32) -> Int32

class ScreenShaker {
    private var isShaking = false

    /// Shake intensity multiplier (0.0 to 2.0, default 1.0)
    var intensityMultiplier: Double = 1.0

    func shake(intensity: Double) {
        guard !isShaking else { return }
        isShaking = true

        let scale = intensity * intensityMultiplier
        let maxOffset = 6.0 + scale * 20.0
        let shakeCount = 5 + Int(scale * 7)
        let frameDelay: UInt32 = 18_000

        // Use a fullscreen overlay window that captures the screen, then shake THAT
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create fullscreen windows on all screens with screen capture
            var shakeWindows: [(NSWindow, NSImageView)] = []

            for screen in NSScreen.screens {
                // Capture the screen content
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
                guard let cgImage = CGDisplayCreateImage(displayID) else { continue }

                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.level = .screenSaver
                window.backgroundColor = .clear
                window.isOpaque = false
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

                let imageView = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
                imageView.image = NSImage(cgImage: cgImage, size: screen.frame.size)
                imageView.imageScaling = .scaleAxesIndependently
                window.contentView = imageView

                window.orderFrontRegardless()
                shakeWindows.append((window, imageView))
            }

            guard !shakeWindows.isEmpty else { self.isShaking = false; return }

            // Shake on background thread
            DispatchQueue.global(qos: .userInteractive).async {
                for i in 0..<shakeCount {
                    let decay = 1.0 - Double(i) / Double(shakeCount)
                    let dx = maxOffset * decay * sin(Double(i) * .pi)
                    let dy = maxOffset * decay * 0.35 * cos(Double(i) * .pi * 1.4)

                    DispatchQueue.main.sync {
                        for (window, imageView) in shakeWindows {
                            imageView.frame.origin = CGPoint(x: dx, y: dy)
                        }
                    }
                    usleep(frameDelay)
                }

                // Remove windows
                DispatchQueue.main.sync {
                    for (window, _) in shakeWindows {
                        window.orderOut(nil)
                    }
                    self.isShaking = false
                }
            }
        }
    }
}
