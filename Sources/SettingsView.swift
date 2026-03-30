import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            SoundsTab()
                .tabItem { Label("Sounds", systemImage: "speaker.wave.3.fill") }
        }
        .frame(width: 400, height: 300)
        .environmentObject(settings)
    }
}

struct GeneralTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Toggle("Show slap count in menu bar", isOn: $settings.showCountInMenuBar)
            Toggle("Screen Flash", isOn: $settings.screenFlashEnabled)
            Toggle("USB Moaner", isOn: $settings.usbMoanerEnabled)

            Picker("Sensitivity", selection: $settings.sensitivity) {
                ForEach(SensitivityLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }

            Picker("Cooldown", selection: Binding(
                get: { CooldownOption(rawValue: settings.cooldownInterval) ?? .medium },
                set: { settings.cooldownInterval = $0.interval }
            )) {
                ForEach(CooldownOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }

            HStack {
                Text("Total Slaps: \(settings.totalSlapCount)")
                Spacer()
                Button("Reset") {
                    settings.totalSlapCount = 0
                    NotificationCenter.default.post(name: .slapCountChanged, object: nil)
                }
            }
        }
        .padding()
    }
}

struct SoundsTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Picker("Voice Pack", selection: $settings.voicePack) {
                ForEach(VoicePack.allCases, id: \.self) { pack in
                    Text(pack.displayName).tag(pack)
                }
            }

            Toggle("Dynamic Volume (scales with slap force)", isOn: $settings.dynamicVolume)

            HStack {
                Text("Volume")
                Slider(value: $settings.volume, in: 0...1)
            }
        }
        .padding()
    }
}
