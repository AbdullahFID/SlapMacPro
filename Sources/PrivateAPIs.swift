import Foundation
import CoreGraphics

// MARK: - Private Framework Loaders

/// Lazy-loaded handles to private frameworks
enum PrivateFrameworks {
    static let skyLight: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    static let displayServices: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    }()

    static let multitouchSupport: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY)
    }()
}

// MARK: - SkyLight (Window Server) Bindings

/// SkyLight / CGS private API bindings for window manipulation
enum SkyLightAPI {
    typealias MainConnectionFunc = @convention(c) () -> Int32
    typealias SetWindowTransformFunc = @convention(c) (Int32, UInt32, CGAffineTransform) -> Int32
    typealias GetWindowTransformFunc = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGAffineTransform>) -> Int32
    typealias SetWindowAlphaFunc = @convention(c) (Int32, UInt32, Float) -> Int32
    typealias GetWindowAlphaFunc = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias MoveWindowFunc = @convention(c) (Int32, UInt32, CGPoint) -> Int32

    static var mainConnectionID: MainConnectionFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSMainConnectionID") else { return nil }
        return unsafeBitCast(sym, to: MainConnectionFunc.self)
    }()

    static var setWindowTransform: SetWindowTransformFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSSetWindowTransform") else { return nil }
        return unsafeBitCast(sym, to: SetWindowTransformFunc.self)
    }()

    static var getWindowTransform: GetWindowTransformFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSGetWindowTransform") else { return nil }
        return unsafeBitCast(sym, to: GetWindowTransformFunc.self)
    }()

    static var setWindowAlpha: SetWindowAlphaFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSSetWindowAlpha") else { return nil }
        return unsafeBitCast(sym, to: SetWindowAlphaFunc.self)
    }()

    static var getWindowAlpha: GetWindowAlphaFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSGetWindowAlpha") else { return nil }
        return unsafeBitCast(sym, to: GetWindowAlphaFunc.self)
    }()

    static var moveWindow: MoveWindowFunc? = {
        guard let fw = PrivateFrameworks.skyLight, let sym = dlsym(fw, "SLSMoveWindow") else { return nil }
        return unsafeBitCast(sym, to: MoveWindowFunc.self)
    }()

    static var connection: Int32 {
        return mainConnectionID?() ?? 0
    }
}

// MARK: - DisplayServices Bindings

/// DisplayServices private API for hardware brightness control
enum DisplayServicesAPI {
    typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightnessFunc = @convention(c) (UInt32, Float) -> Int32
    typealias SetBrightnessSmoothFunc = @convention(c) (UInt32, Float) -> Int32

    static var getBrightness: GetBrightnessFunc? = {
        guard let fw = PrivateFrameworks.displayServices, let sym = dlsym(fw, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFunc.self)
    }()

    static var setBrightness: SetBrightnessFunc? = {
        guard let fw = PrivateFrameworks.displayServices, let sym = dlsym(fw, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFunc.self)
    }()

    static var setBrightnessSmooth: SetBrightnessSmoothFunc? = {
        guard let fw = PrivateFrameworks.displayServices, let sym = dlsym(fw, "DisplayServicesSetBrightnessSmooth") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessSmoothFunc.self)
    }()
}

// MARK: - MultitouchSupport Bindings

/// MultitouchSupport private API for trackpad haptic feedback
enum MultitouchAPI {
    typealias DeviceCreateListFunc = @convention(c) () -> CFArray
    typealias ActuatorCreateFunc = @convention(c) (Int32) -> OpaquePointer?
    typealias ActuatorOpenFunc = @convention(c) (OpaquePointer) -> Int32
    typealias ActuatorCloseFunc = @convention(c) (OpaquePointer) -> Int32
    // MTActuatorActuate(actuator, actuationID, unknown1, unknown2, unknown3)
    typealias ActuatorActuateFunc = @convention(c) (OpaquePointer, Int32, UInt32, Float, Float) -> Int32

    static var deviceCreateList: DeviceCreateListFunc? = {
        guard let fw = PrivateFrameworks.multitouchSupport, let sym = dlsym(fw, "MTDeviceCreateList") else { return nil }
        return unsafeBitCast(sym, to: DeviceCreateListFunc.self)
    }()

    static var actuatorCreateFromDeviceID: ActuatorCreateFunc? = {
        guard let fw = PrivateFrameworks.multitouchSupport, let sym = dlsym(fw, "MTActuatorCreateFromDeviceID") else { return nil }
        return unsafeBitCast(sym, to: ActuatorCreateFunc.self)
    }()

    static var actuatorOpen: ActuatorOpenFunc? = {
        guard let fw = PrivateFrameworks.multitouchSupport, let sym = dlsym(fw, "MTActuatorOpen") else { return nil }
        return unsafeBitCast(sym, to: ActuatorOpenFunc.self)
    }()

    static var actuatorClose: ActuatorCloseFunc? = {
        guard let fw = PrivateFrameworks.multitouchSupport, let sym = dlsym(fw, "MTActuatorClose") else { return nil }
        return unsafeBitCast(sym, to: ActuatorCloseFunc.self)
    }()

    static var actuatorActuate: ActuatorActuateFunc? = {
        guard let fw = PrivateFrameworks.multitouchSupport, let sym = dlsym(fw, "MTActuatorActuate") else { return nil }
        return unsafeBitCast(sym, to: ActuatorActuateFunc.self)
    }()
}
