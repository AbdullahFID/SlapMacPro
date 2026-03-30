import Foundation

/// Unbuffered logging to stderr so output is visible from GUI apps
func log(_ message: String) {
    fputs("[SlapClone] \(message)\n", stderr)
}
