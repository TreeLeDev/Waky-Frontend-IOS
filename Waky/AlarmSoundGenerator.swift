//
//  AlarmSoundGenerator.swift
//  Waky
//
//  Generates alarm sound programmatically when no audio file is available
//  Creates a loud, attention-grabbing beep tone
//

import AVFoundation
import Accelerate

class AlarmSoundGenerator {
    /// Generate a loud alarm beep audio file
    /// Returns URL to temporary audio file
    static func generateAlarmSound() -> URL? {
        let sampleRate = 44100.0
        let duration = 2.0  // 2 seconds per beep
        let frequency = 880.0  // A5 note (high pitched)

        // Calculate number of samples
        let sampleCount = Int(sampleRate * duration)

        // Generate sine wave samples
        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let time = Float(i) / Float(sampleRate)
            // Create pulsing effect
            let envelope = sin(Float(time * 4 * .pi))  // 4 pulses per 2 seconds
            samples[i] = sin(2.0 * .pi * Float(frequency) * time) * 0.9 * abs(envelope)
        }

        // Create audio file
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )

        guard let format = format else {
            print("❌ Failed to create audio format")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else {
            print("❌ Failed to create audio buffer")
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // Copy samples to buffer
        if let channelData = buffer.floatChannelData {
            for i in 0..<sampleCount {
                channelData[0][i] = samples[i]
            }
        }

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("alarm_sound.m4a")

        // Delete existing file if present
        try? FileManager.default.removeItem(at: fileURL)

        do {
            let file = try AVAudioFile(
                forWriting: fileURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )

            try file.write(from: buffer)
            print("✅ Generated alarm sound at: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to write audio file: \(error)")
            return nil
        }
    }
}
