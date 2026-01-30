//
//  BackgroundAlarmAudioManager.swift
//  Waky
//
//  App Store compliant background alarm audio manager
//  Uses official AVAudioSession APIs only - no private API usage
//

import AVFoundation
import Observation

enum AlarmAudioError: Error {
    case soundNotFound
    case audioSessionFailed
    case playerInitFailed
}

@Observable class BackgroundAlarmAudioManager {
    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var volumeObserver: NSKeyValueObservation?
    private(set) var isPlaying = false
    private(set) var currentVolume: Float = 0.0

    init() {
        setupAudioSession()
    }

    deinit {
        stopAlarm()
    }

    /// Configure audio session for background playback
    /// Uses OFFICIAL Apple APIs - App Store compliant
    private func setupAudioSession() {
        do {
            // Use .playAndRecord category (required for .defaultToSpeaker)
            // This is OFFICIALLY DOCUMENTED by Apple
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [
                    .defaultToSpeaker,  // Routes to louder speaker instead of earpiece
                    .duckOthers         // Lower volume of other audio
                ]
            )
            print("✅ Audio session configured: .playAndRecord + .defaultToSpeaker")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }

    /// Start playing alarm with background audio support
    /// - Parameter soundFile: Name of sound file (without extension)
    func startBackgroundAlarm(soundFile: String = "alarm_sound") throws {
        print("🎵 Starting background alarm audio...")

        // Activate audio session
        do {
            try audioSession.setActive(true)
            print("✅ Audio session activated")
        } catch {
            print("❌ Failed to activate audio session: \(error)")
            throw AlarmAudioError.audioSessionFailed
        }

        // Try to load alarm sound from bundle
        if let soundURL = Bundle.main.url(forResource: soundFile, withExtension: "mp3") {
            print("✅ Found sound file: \(soundFile).mp3")
            try startPlayer(with: soundURL)
            return
        }

        // Try with .m4a extension
        if let m4aURL = Bundle.main.url(forResource: soundFile, withExtension: "m4a") {
            print("✅ Found sound file: \(soundFile).m4a")
            try startPlayer(with: m4aURL)
            return
        }

        // If no custom sound found, generate one programmatically
        print("⚠️ No custom alarm sound found, generating default beep...")
        if let generatedURL = AlarmSoundGenerator.generateAlarmSound() {
            print("✅ Using generated alarm sound")
            try startPlayer(with: generatedURL)
        } else {
            print("❌ Failed to generate alarm sound")
            throw AlarmAudioError.soundNotFound
        }
    }

    private func startPlayer(with url: URL) throws {
        do {
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // Infinite loop until stopped
            audioPlayer?.volume = 1.0        // Maximum player volume
            audioPlayer?.prepareToPlay()

            // Start playing
            let success = audioPlayer?.play() ?? false
            if success {
                isPlaying = true
                print("✅ Background alarm audio started")
                print("📊 Player volume: \(audioPlayer?.volume ?? 0.0)")
                print("📊 System volume: \(audioSession.outputVolume)")

                // Start monitoring volume for warnings (NOT for forcing)
                startVolumeMonitoring()
            } else {
                print("❌ Failed to start audio player")
                throw AlarmAudioError.playerInitFailed
            }
        } catch {
            print("❌ Failed to create audio player: \(error)")
            throw AlarmAudioError.playerInitFailed
        }
    }

    /// Monitor system volume changes
    /// Uses OFFICIAL KVO on AVAudioSession.outputVolume - App Store compliant
    /// NOTE: This only monitors - it does NOT force volume up
    private func startVolumeMonitoring() {
        print("👂 Starting volume monitoring...")

        // Use official AVAudioSession.outputVolume property
        // This is DOCUMENTED and App Store compliant
        volumeObserver = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            if let newVolume = change.newValue {
                self?.currentVolume = newVolume
                print("📊 Volume changed to: \(Int(newVolume * 100))%")

                // Notify if volume is too low (but don't force it up)
                if newVolume < 0.3 {
                    print("⚠️ WARNING: Volume is very low (\(Int(newVolume * 100))%)")
                    self?.handleLowVolume(newVolume)
                }
            }
        }
    }

    /// Handle low volume detection
    /// Shows warning notification - does NOT force volume up (App Store compliant)
    private func handleLowVolume(_ volume: Float) {
        // Post notification for UI to show warning
        NotificationCenter.default.post(
            name: NSNotification.Name("LowVolumeWarning"),
            object: nil,
            userInfo: ["volume": volume]
        )
    }

    /// Stop alarm audio and cleanup
    func stopAlarm() {
        print("🛑 Stopping background alarm audio...")

        // Stop player
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        // Stop volume monitoring
        volumeObserver?.invalidate()
        volumeObserver = nil

        // Deactivate audio session
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    /// Check if alarm is currently playing
    var isAlarmPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }

    /// Get current system volume (0.0 to 1.0)
    var systemVolume: Float {
        return audioSession.outputVolume
    }
}
