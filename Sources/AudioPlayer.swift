import Foundation
import AVFoundation

/// Audio player with voice pack support, escalation tracking, and logarithmic
/// volume scaling. For packs like "sexy" and "yamete", sustained slapping
/// escalates through increasingly intense sound files.
class AudioPlayer {
    private var players: [AVAudioPlayer] = []
    private var comboAnnouncerPlayers: [AVAudioPlayer] = []
    private var currentPack: VoicePack = .sexy

    // Escalation tracking (inspired by spank's slapTracker)
    private var escalationScore: Double = 0
    private var lastSlapTime: Date = .distantPast
    private let escalationDecayHalfLife: TimeInterval = 30.0  // seconds

    /// Directory containing the sound files
    private let audioDirectory: URL

    init() {
        // Search for audio files in common locations
        let homeAudioDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/slapmac/audio")

        if FileManager.default.fileExists(atPath: homeAudioDir.path) {
            audioDirectory = homeAudioDir
        } else if let bundlePath = Bundle.main.resourcePath {
            audioDirectory = URL(fileURLWithPath: bundlePath)
        } else {
            audioDirectory = homeAudioDir
        }

        log("Audio directory: \(audioDirectory.path)")
        loadSounds(for: .sexy)
    }

    func loadSounds(for pack: VoicePack) {
        currentPack = pack
        players.removeAll()
        comboAnnouncerPlayers.removeAll()
        escalationScore = 0

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: audioDirectory.path) else {
            log("Could not list audio directory")
            return
        }

        let packFiles = files.filter { file in
            let lower = file.lowercased()
            return lower.hasPrefix(pack.filePrefix + "_") &&
                   (lower.hasSuffix(".mp3") || lower.hasSuffix(".wav"))
        }.sorted()

        for file in packFiles {
            let url = audioDirectory.appendingPathComponent(file)
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players.append(player)
            } catch {
                log("Failed to load \(file): \(error)")
            }
        }

        // Load combo announcer files (numbered packs 1_x through 9_x)
        if pack == .comboHit {
            for prefix in 1...9 {
                let announcerFiles = files.filter { file in
                    let lower = file.lowercased()
                    return lower.hasPrefix("\(prefix)_") &&
                           (lower.hasSuffix(".mp3") || lower.hasSuffix(".wav"))
                }.sorted()

                for file in announcerFiles {
                    let url = audioDirectory.appendingPathComponent(file)
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        player.prepareToPlay()
                        comboAnnouncerPlayers.append(player)
                    }
                }
            }
        }

        log("Loaded \(players.count) sounds for '\(pack.displayName)'" +
              (comboAnnouncerPlayers.isEmpty ? "" : " + \(comboAnnouncerPlayers.count) combo clips"))
    }

    /// Play a sound from the current pack
    func play(intensity: Double, dynamicVolume: Bool, baseVolume: Float) {
        guard !players.isEmpty else { return }

        // Update escalation score with time decay
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSlapTime)
        let decayFactor = pow(0.5, elapsed / escalationDecayHalfLife)
        escalationScore = escalationScore * decayFactor + 1.0
        lastSlapTime = now

        // Select sound based on escalation level
        let player: AVAudioPlayer
        if currentPack.usesEscalation && players.count > 1 {
            // Map escalation score to file index using exponential curve
            // Higher score = later (more intense) files
            let normalized = 1.0 - exp(-(escalationScore - 1) / 5.0)
            let index = min(Int(normalized * Double(players.count)), players.count - 1)
            player = players[index]
        } else {
            player = players.randomElement()!
        }

        // Apply volume
        if dynamicVolume {
            // Logarithmic volume scaling (like spank)
            // Maps intensity [0, 1] to volume [0.125, 1.0] (1/8 to full)
            let minVol: Float = 0.125
            let maxVol: Float = 1.0
            let scaledVol = minVol + Float(intensity) * (maxVol - minVol)
            player.volume = baseVolume * scaledVol
        } else {
            player.volume = baseVolume
        }

        player.currentTime = 0
        player.play()

        // Play combo announcer for combo hit pack
        if currentPack == .comboHit && !comboAnnouncerPlayers.isEmpty {
            // Select announcer based on combo tier
            let tier = min(Int(escalationScore) - 1, comboAnnouncerPlayers.count - 1)
            if tier >= 0 && tier < comboAnnouncerPlayers.count {
                let announcer = comboAnnouncerPlayers[tier]
                announcer.volume = baseVolume * 0.7
                announcer.currentTime = 0
                announcer.play()
            }
        }
    }

    /// Play a random sound for USB events (no escalation)
    func playRandom(baseVolume: Float) {
        guard !players.isEmpty else { return }
        let player = players.randomElement()!
        player.volume = baseVolume
        player.currentTime = 0
        player.play()
    }
}
