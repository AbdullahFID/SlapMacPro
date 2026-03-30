import Foundation
import CoreGraphics

// MARK: - CGS/SkyLight Private API via @_silgen_name
// These bind directly to WindowServer symbols — no dlopen needed.
// _CGSDefaultConnection gives us a connection that can transform ALL windows,
// not just our own process's windows.

@_silgen_name("_CGSDefaultConnection")
func CGSDefaultConnection() -> UInt32

@_silgen_name("CGSSetWindowTransform")
func CGSSetWindowTransform(_ cid: UInt32, _ wid: UInt32, _ transform: CGAffineTransform) -> Int32

@_silgen_name("CGSGetWindowTransform")
func CGSGetWindowTransform(_ cid: UInt32, _ wid: UInt32, _ transform: UnsafeMutablePointer<CGAffineTransform>) -> Int32

@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(_ cid: UInt32, _ wid: UInt32, _ alpha: Float) -> Int32

// MARK: - DisplayServices Private API

/// Lazy-loaded DisplayServices framework handle
private let displayServicesHandle: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
}()

enum DisplayServicesAPI {
    typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightnessFunc = @convention(c) (UInt32, Float) -> Int32

    static var getBrightness: GetBrightnessFunc? = {
        guard let fw = displayServicesHandle, let sym = dlsym(fw, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFunc.self)
    }()

    static var setBrightness: SetBrightnessFunc? = {
        guard let fw = displayServicesHandle, let sym = dlsym(fw, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFunc.self)
    }()
}
