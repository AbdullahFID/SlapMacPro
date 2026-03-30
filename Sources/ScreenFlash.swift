import AppKit

/// Flashes the screen with a translucent overlay on impact
class ScreenFlash {
    private var flashWindows: [NSWindow] = []

    func flash(intensity: Double) {
        // Create a flash overlay on each screen
        for screen in NSScreen.screens {
            let window = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.backgroundColor = NSColor.white.withAlphaComponent(CGFloat(intensity) * 0.4)
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.orderFront(nil)

            flashWindows.append(window)

            // Fade out
            let duration = 0.15 + (intensity * 0.2)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
                self.flashWindows.removeAll { $0 === window }
            })
        }
    }
}
