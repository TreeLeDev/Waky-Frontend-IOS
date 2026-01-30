//
//  HapticAlarmManager.swift
//  Waky
//
//  Provides continuous haptic feedback for alarms
//  Works even when volume is muted or in silent mode
//

import CoreHaptics
import Observation

@Observable class HapticAlarmManager {
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticPatternPlayer?
    private(set) var isVibrating = false

    init() {
        setupHapticEngine()
    }

    deinit {
        stopVibration()
    }

    /// Setup Core Haptics engine
    private func setupHapticEngine() {
        // Check if device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ Device doesn't support haptics")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            print("✅ Haptic engine created")

            // Handle engine stopped
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("⚠️ Haptic engine stopped: \(reason)")
                self?.isVibrating = false
            }

            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                print("🔄 Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                    self?.restartVibrationIfNeeded()
                } catch {
                    print("❌ Failed to restart haptic engine: \(error)")
                }
            }

            // Start the engine
            try hapticEngine?.start()
            print("✅ Haptic engine started")
        } catch {
            print("❌ Failed to setup haptic engine: \(error)")
        }
    }

    /// Start continuous vibration pattern
    /// Creates an intense, attention-grabbing haptic pattern
    func startContinuousVibration() {
        print("📳 Starting continuous vibration...")

        guard let engine = hapticEngine else {
            print("❌ Haptic engine not available")
            return
        }

        do {
            // Ensure engine is running
            try engine.start()

            // Create intense vibration pattern
            let pattern = try createAlarmHapticPattern()
            hapticPlayer = try engine.makePlayer(with: pattern)

            // Start playing
            try hapticPlayer?.start(atTime: CHHapticTimeImmediate)
            isVibrating = true
            print("✅ Continuous vibration started")

            // Schedule to restart every 10 seconds (pattern loops)
            scheduleVibrationLoop()
        } catch {
            print("❌ Failed to start vibration: \(error)")
        }
    }

    /// Create alarm haptic pattern
    /// Returns an intense, pulsing vibration pattern
    private func createAlarmHapticPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Create pulsing pattern (0.5s vibration, 0.2s pause, repeat)
        let pulseDuration: TimeInterval = 0.5
        let pauseDuration: TimeInterval = 0.2
        let totalDuration: TimeInterval = 10.0  // 10 seconds total
        var time: TimeInterval = 0

        while time < totalDuration {
            // Strong vibration pulse
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: time,
                duration: pulseDuration
            )
            events.append(event)

            time += pulseDuration + pauseDuration
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Schedule vibration to loop continuously
    private func scheduleVibrationLoop() {
        // Restart the pattern after 10 seconds if still vibrating
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.isVibrating else { return }

            print("🔄 Restarting vibration loop...")
            do {
                try self.hapticPlayer?.start(atTime: CHHapticTimeImmediate)
                self.scheduleVibrationLoop()  // Schedule next loop
            } catch {
                print("❌ Failed to restart vibration loop: \(error)")
            }
        }
    }

    /// Restart vibration if it was active (after engine reset)
    private func restartVibrationIfNeeded() {
        if isVibrating {
            print("🔄 Restarting vibration after engine reset...")
            startContinuousVibration()
        }
    }

    /// Stop vibration
    func stopVibration() {
        print("🛑 Stopping vibration...")

        do {
            try hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            isVibrating = false
            print("✅ Vibration stopped")
        } catch {
            print("⚠️ Failed to stop vibration: \(error)")
        }

        hapticPlayer = nil
    }

    /// Quick vibration for button feedback
    func playButtonTap() {
        guard let engine = hapticEngine else { return }

        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("⚠️ Failed to play button tap: \(error)")
        }
    }
}
