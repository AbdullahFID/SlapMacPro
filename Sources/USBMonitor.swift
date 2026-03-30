import Foundation
import IOKit
import IOKit.usb

/// Monitors USB device plug/unplug events using IOKit notifications.
/// Watches multiple service classes to catch USB-C devices on Apple Silicon:
/// - IOUSBHostDevice (traditional USB)
/// - IOUSBHostInterface (USB interfaces, appears when phones plug in)
/// Also uses DistributedNotificationCenter as a fallback for broader coverage.
class USBMonitor {
    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var isRunning = false

    var onUSBEvent: (() -> Void)?

    func start() {
        guard !isRunning else { return }

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else {
            log("USB monitor: Failed to create notification port")
            return
        }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Watch multiple service classes for maximum compatibility
        let watchClasses = ["IOUSBHostDevice", "IOUSBHostInterface"]

        for className in watchClasses {
            // Watch for new devices (publish)
            if let matching = IOServiceMatching(className) {
                var addedIter: io_iterator_t = 0
                let kr = IOServiceAddMatchingNotification(
                    notifyPort,
                    kIOPublishNotification,
                    matching,
                    { (refcon, iterator) in
                        guard let refcon = refcon else {
                            // Still drain
                            var e = IOIteratorNext(iterator); while e != 0 { IOObjectRelease(e); e = IOIteratorNext(iterator) }
                            return
                        }
                        let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                        var entry = IOIteratorNext(iterator)
                        while entry != 0 {
                            log("USB device connected!")
                            monitor.onUSBEvent?()
                            IOObjectRelease(entry)
                            entry = IOIteratorNext(iterator)
                        }
                    },
                    selfPtr,
                    &addedIter
                )
                if kr == KERN_SUCCESS {
                    // Drain initial matches
                    var e = IOIteratorNext(addedIter); while e != 0 { IOObjectRelease(e); e = IOIteratorNext(addedIter) }
                    iterators.append(addedIter)
                }
            }

            // Watch for device removal (terminated)
            if let matching = IOServiceMatching(className) {
                var removedIter: io_iterator_t = 0
                let kr = IOServiceAddMatchingNotification(
                    notifyPort,
                    kIOTerminatedNotification,
                    matching,
                    { (refcon, iterator) in
                        guard let refcon = refcon else {
                            var e = IOIteratorNext(iterator); while e != 0 { IOObjectRelease(e); e = IOIteratorNext(iterator) }
                            return
                        }
                        let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                        var entry = IOIteratorNext(iterator)
                        while entry != 0 {
                            log("USB device disconnected!")
                            monitor.onUSBEvent?()
                            IOObjectRelease(entry)
                            entry = IOIteratorNext(iterator)
                        }
                    },
                    selfPtr,
                    &removedIter
                )
                if kr == KERN_SUCCESS {
                    var e = IOIteratorNext(removedIter); while e != 0 { IOObjectRelease(e); e = IOIteratorNext(removedIter) }
                    iterators.append(removedIter)
                }
            }
        }

        // Also watch via DistributedNotificationCenter for broader USB events
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(distributedUSBNotification(_:)),
            name: NSNotification.Name("com.apple.iokit.matching"),
            object: nil
        )

        isRunning = true
        log("USB monitor started (watching \(watchClasses.joined(separator: ", ")))")
    }

    @objc private func distributedUSBNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let ioClass = userInfo["IOClass"] as? String,
           ioClass.contains("USB") {
            log("USB event via distributed notification: \(ioClass)")
            onUSBEvent?()
        }
    }

    func stop() {
        guard isRunning else { return }
        for iter in iterators {
            IOObjectRelease(iter)
        }
        iterators.removeAll()
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        DistributedNotificationCenter.default().removeObserver(self)
        isRunning = false
        log("USB monitor stopped")
    }
}
