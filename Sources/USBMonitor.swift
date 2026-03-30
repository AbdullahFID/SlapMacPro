import Foundation
import IOKit
import IOKit.usb

/// Monitors USB device plug/unplug events using IOKit notifications
class USBMonitor {
    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var isRunning = false

    var onUSBEvent: (() -> Void)?

    func start() {
        guard !isRunning else { return }

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else {
            log("Failed to create notification port")
            return
        }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        guard let matchingDict = IOServiceMatching("IOUSBHostDevice") else {
            log("Failed to create matching dict")
            return
        }

        // Register for device arrival
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let addResult = IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingDict,
            { (refcon, iterator) in
                guard let refcon = refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                // Drain the iterator
                var entry: io_object_t = 0
                var isFirst = true
                while true {
                    entry = IOIteratorNext(iterator)
                    if entry == 0 { break }
                    if !isFirst {
                        monitor.onUSBEvent?()
                    }
                    isFirst = false
                    IOObjectRelease(entry)
                }
            },
            selfPtr,
            &addedIterator
        )

        // Drain initial iterator
        var entry: io_object_t = 0
        while true {
            entry = IOIteratorNext(addedIterator)
            if entry == 0 { break }
            IOObjectRelease(entry)
        }

        // Register for device removal
        guard let removeMatchingDict = IOServiceMatching("IOUSBHostDevice") else {
            log("Failed to create removal matching dict")
            return
        }
        let removeResult = IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            removeMatchingDict,
            { (refcon, iterator) in
                guard let refcon = refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                var entry: io_object_t = 0
                while true {
                    entry = IOIteratorNext(iterator)
                    if entry == 0 { break }
                    monitor.onUSBEvent?()
                    IOObjectRelease(entry)
                }
            },
            selfPtr,
            &removedIterator
        )

        // Drain initial removal iterator
        while true {
            entry = IOIteratorNext(removedIterator)
            if entry == 0 { break }
            IOObjectRelease(entry)
        }

        if addResult == KERN_SUCCESS && removeResult == KERN_SUCCESS {
            isRunning = true
            log("USB monitor started")
        } else {
            log("USB monitor failed to start (add: \(addResult), remove: \(removeResult))")
        }
    }

    func stop() {
        guard isRunning else { return }
        if addedIterator != 0 { IOObjectRelease(addedIterator); addedIterator = 0 }
        if removedIterator != 0 { IOObjectRelease(removedIterator); removedIterator = 0 }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        isRunning = false
        log("USB monitor stopped")
    }
}
