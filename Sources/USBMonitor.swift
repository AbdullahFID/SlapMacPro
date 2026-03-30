import Foundation
import IOKit
import IOKit.usb
import AppKit

/// Monitors USB/Thunderbolt device plug/unplug events.
/// Uses multiple strategies for Apple Silicon USB-C compatibility:
/// 1. IOKit publish/terminated notifications for IOUSBHostDevice
/// 2. NSWorkspace DiskMount/Unmount notifications
/// 3. Darwin notify for com.apple.iokit.matching
/// 4. Polling IOServiceGetMatchingServices as a fallback
class USBMonitor {
    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var isRunning = false
    private var pollTimer: Timer?
    private var lastDeviceCount: Int = 0

    var onUSBEvent: (() -> Void)?

    func start() {
        guard !isRunning else { return }

        // Strategy 1: IOKit notifications
        setupIOKitNotifications()

        // Strategy 2: NSWorkspace volume mount/unmount (catches USB drives)
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(deviceMounted), name: NSWorkspace.didMountNotification, object: nil)
        ws.addObserver(self, selector: #selector(deviceMounted), name: NSWorkspace.didUnmountNotification, object: nil)

        // Strategy 3: Poll for device count changes every 2 seconds
        // This is the most reliable fallback for M5 Thunderbolt USB-C
        lastDeviceCount = countUSBDevices()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForDeviceChanges()
        }

        isRunning = true
        log("USB monitor started (IOKit + NSWorkspace + polling)")
    }

    private func setupIOKitNotifications() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let watchClasses = ["IOUSBHostDevice", "IOUSBHostInterface"]

        for className in watchClasses {
            for notification in [kIOPublishNotification, kIOTerminatedNotification] {
                guard let matching = IOServiceMatching(className) else { continue }
                var iter: io_iterator_t = 0
                let kr = IOServiceAddMatchingNotification(
                    notifyPort, notification, matching,
                    { (refcon, iterator) in
                        guard let refcon = refcon else {
                            var e = IOIteratorNext(iterator)
                            while e != 0 { IOObjectRelease(e); e = IOIteratorNext(iterator) }
                            return
                        }
                        let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                        var found = false
                        var entry = IOIteratorNext(iterator)
                        while entry != 0 {
                            found = true
                            IOObjectRelease(entry)
                            entry = IOIteratorNext(iterator)
                        }
                        if found {
                            log("USB event (IOKit notification)")
                            monitor.onUSBEvent?()
                        }
                    },
                    selfPtr, &iter
                )
                if kr == KERN_SUCCESS {
                    // Drain initial
                    var e = IOIteratorNext(iter)
                    while e != 0 { IOObjectRelease(e); e = IOIteratorNext(iter) }
                    iterators.append(iter)
                }
            }
        }
    }

    @objc private func deviceMounted(_ notification: Notification) {
        log("USB event (volume mount/unmount)")
        onUSBEvent?()
    }

    private func countUSBDevices() -> Int {
        var total = 0
        for cls in ["IOUSBHostDevice", "IOUSBHostInterface", "AppleUSBHostPort"] {
            var iter: io_iterator_t = 0
            guard let matching = IOServiceMatching(cls) else { continue }
            if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
                var svc = IOIteratorNext(iter)
                while svc != 0 { total += 1; IOObjectRelease(svc); svc = IOIteratorNext(iter) }
                IOObjectRelease(iter)
            }
        }
        return total
    }

    private func checkForDeviceChanges() {
        let current = countUSBDevices()
        if current != lastDeviceCount {
            log("USB event (poll: \(lastDeviceCount) -> \(current) devices)")
            lastDeviceCount = current
            onUSBEvent?()
        }
    }

    func stop() {
        guard isRunning else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        for iter in iterators { IOObjectRelease(iter) }
        iterators.removeAll()
        if let port = notifyPort { IONotificationPortDestroy(port); notifyPort = nil }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isRunning = false
        log("USB monitor stopped")
    }
}
