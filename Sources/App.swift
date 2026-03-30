import SwiftUI

@main
struct SlapMacCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a Settings scene but it's optional — the main UI is the menu bar
        Settings {
            if let controller = appDelegate.slapController {
                SettingsView()
                    .environmentObject(appDelegate.settings)
                    .environmentObject(controller)
            } else {
                Text("Loading...")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let settings = SettingsStore()
    var slapController: SlapController?
    var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        slapController = SlapController(settings: settings)

        setupMenuBar()
        slapController?.start()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "👋 \(settings.totalSlapCount)"
        }

        statusMenu = NSMenu()
        rebuildMenu()
        statusItem.menu = statusMenu

        NotificationCenter.default.addObserver(
            self, selector: #selector(slapCountChanged),
            name: .slapCountChanged, object: nil
        )
    }

    func rebuildMenu() {
        statusMenu.removeAllItems()

        let enableItem = NSMenuItem(
            title: settings.isEnabled ? "Enabled" : "Disabled",
            action: #selector(toggleEnabled), keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = settings.isEnabled ? .on : .off
        statusMenu.addItem(enableItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Voice pack submenu
        let voiceMenu = NSMenu()
        for pack in VoicePack.allCases {
            let item = NSMenuItem(title: pack.displayName, action: #selector(selectVoicePack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.rawValue
            item.state = settings.voicePack == pack ? .on : .off
            voiceMenu.addItem(item)
        }
        let voiceItem = NSMenuItem(title: "Voice Pack", action: nil, keyEquivalent: "")
        voiceItem.submenu = voiceMenu
        statusMenu.addItem(voiceItem)

        // Sensitivity submenu
        let sensMenu = NSMenu()
        for level in SensitivityLevel.allCases {
            let item = NSMenuItem(title: level.displayName, action: #selector(selectSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level.rawValue
            item.state = settings.sensitivity == level ? .on : .off
            sensMenu.addItem(item)
        }
        let sensItem = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        sensItem.submenu = sensMenu
        statusMenu.addItem(sensItem)

        // Cooldown submenu
        let cdMenu = NSMenu()
        for cd in CooldownOption.allCases {
            let item = NSMenuItem(title: cd.displayName, action: #selector(selectCooldown(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = cd.rawValue
            item.state = settings.cooldownInterval == cd.interval ? .on : .off
            cdMenu.addItem(item)
        }
        let cdItem = NSMenuItem(title: "Cooldown", action: nil, keyEquivalent: "")
        cdItem.submenu = cdMenu
        statusMenu.addItem(cdItem)

        // Dynamic volume toggle
        let dynVolItem = NSMenuItem(
            title: "Dynamic Volume",
            action: #selector(toggleDynamicVolume), keyEquivalent: ""
        )
        dynVolItem.target = self
        dynVolItem.state = settings.dynamicVolume ? .on : .off
        statusMenu.addItem(dynVolItem)

        // Screen flash toggle
        let flashItem = NSMenuItem(
            title: "Screen Flash",
            action: #selector(toggleScreenFlash), keyEquivalent: ""
        )
        flashItem.target = self
        flashItem.state = settings.screenFlashEnabled ? .on : .off
        statusMenu.addItem(flashItem)

        // Screen Shake toggle (SkyLight private API)
        let shakeItem = NSMenuItem(
            title: "Screen Shake ⚡",
            action: #selector(toggleScreenShake), keyEquivalent: ""
        )
        shakeItem.target = self
        shakeItem.state = settings.screenShakeEnabled ? .on : .off
        statusMenu.addItem(shakeItem)

        // Brightness Flash toggle (DisplayServices private API)
        let brItem = NSMenuItem(
            title: "Brightness Flash 💡",
            action: #selector(toggleBrightnessFlash), keyEquivalent: ""
        )
        brItem.target = self
        brItem.state = settings.brightnessFlashEnabled ? .on : .off
        statusMenu.addItem(brItem)

        // Haptic Feedback toggle (MultitouchSupport private API)
        let hapticItem = NSMenuItem(
            title: "Haptic Feedback 📳",
            action: #selector(toggleHapticFeedback), keyEquivalent: ""
        )
        hapticItem.target = self
        hapticItem.state = settings.hapticFeedbackEnabled ? .on : .off
        statusMenu.addItem(hapticItem)

        // USB Moaner toggle
        let usbItem = NSMenuItem(
            title: "USB Moaner",
            action: #selector(toggleUSBMonitor), keyEquivalent: ""
        )
        usbItem.target = self
        usbItem.state = settings.usbMoanerEnabled ? .on : .off
        statusMenu.addItem(usbItem)

        statusMenu.addItem(NSMenuItem.separator())

        let resetItem = NSMenuItem(title: "Reset Slap Count", action: #selector(resetCount), keyEquivalent: "")
        resetItem.target = self
        statusMenu.addItem(resetItem)

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    @objc func toggleEnabled() {
        settings.isEnabled.toggle()
        if settings.isEnabled {
            slapController?.start()
        } else {
            slapController?.stop()
        }
        rebuildMenu()
    }

    @objc func selectVoicePack(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let pack = VoicePack(rawValue: raw) {
            settings.voicePack = pack
            slapController?.audioPlayer.loadSounds(for: pack)
        }
        rebuildMenu()
    }

    @objc func selectSensitivity(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? Int, let level = SensitivityLevel(rawValue: raw) {
            settings.sensitivity = level
            slapController?.updateDetectorConfig()
        }
        rebuildMenu()
    }

    @objc func selectCooldown(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? Double {
            settings.cooldownInterval = raw
        }
        rebuildMenu()
    }

    @objc func toggleDynamicVolume() {
        settings.dynamicVolume.toggle()
        rebuildMenu()
    }

    @objc func toggleScreenFlash() {
        settings.screenFlashEnabled.toggle()
        rebuildMenu()
    }

    @objc func toggleScreenShake() {
        settings.screenShakeEnabled.toggle()
        rebuildMenu()
    }

    @objc func toggleBrightnessFlash() {
        settings.brightnessFlashEnabled.toggle()
        rebuildMenu()
    }

    @objc func toggleHapticFeedback() {
        settings.hapticFeedbackEnabled.toggle()
        rebuildMenu()
    }

    @objc func toggleUSBMonitor() {
        settings.usbMoanerEnabled.toggle()
        if settings.usbMoanerEnabled {
            slapController?.usbMonitor.start()
        } else {
            slapController?.usbMonitor.stop()
        }
        rebuildMenu()
    }

    @objc func resetCount() {
        settings.totalSlapCount = 0
        slapCountChanged()
    }

    @objc func slapCountChanged() {
        if let button = statusItem?.button {
            if settings.showCountInMenuBar {
                button.title = "👋 \(settings.totalSlapCount)"
            } else {
                button.title = "👋"
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let slapCountChanged = Notification.Name("slapCountChanged")
    static let settingsChanged = Notification.Name("settingsChanged")
}
