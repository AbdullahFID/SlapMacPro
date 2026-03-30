import Foundation
import AppKit

/// Triggers haptic feedback on the MacBook's trackpad.
/// Tries MTActuator (private API) first for fine-grained control,
/// falls back to NSHapticFeedbackManager (public API).
class HapticFeedback {
    private var usePublicAPI = true

    init() {
        // On most unsigned binaries, MTActuator won't work.
        // Go straight to the public API which always works.
        log("HapticFeedback: Using NSHapticFeedbackManager")
    }

    /// Fire the Taptic Engine
    func buzz(intensity: Double) {
        // NSHapticFeedbackManager — reliable, works on all MacBooks with Force Touch
        DispatchQueue.main.async {
            let performer = NSHapticFeedbackManager.defaultPerformer
            if intensity > 0.6 {
                // Strong: perform multiple times for a bigger buzz
                performer.perform(.generic, performanceTime: .now)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    performer.perform(.generic, performanceTime: .now)
                }
            } else if intensity > 0.3 {
                performer.perform(.generic, performanceTime: .now)
            } else {
                performer.perform(.alignment, performanceTime: .now)
            }
        }
    }
}
