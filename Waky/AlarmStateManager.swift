//
//  AlarmStateManager.swift
//  Waky
//
//  Manages persistent alarm state across app launches
//  Ensures alarm resumes even after force-kill
//

import Foundation

struct ActiveAlarmState: Codable {
    let alarmID: String
    let nfcTagID: String
    let startTimestamp: TimeInterval
    let isActive: Bool
}

class AlarmStateManager {
    static let shared = AlarmStateManager()

    private let userDefaults = UserDefaults.standard
    private let activeAlarmKey = "com.waky.activeAlarm"

    private init() {}

    /// Save active alarm state
    func saveActiveAlarm(alarmID: String, nfcTagID: String) {
        let state = ActiveAlarmState(
            alarmID: alarmID,
            nfcTagID: nfcTagID,
            startTimestamp: Date().timeIntervalSince1970,
            isActive: true
        )

        if let encoded = try? JSONEncoder().encode(state) {
            userDefaults.set(encoded, forKey: activeAlarmKey)
            userDefaults.synchronize()
            print("💾 Saved active alarm state: \(alarmID)")
        }
    }

    /// Get active alarm state
    func getActiveAlarm() -> ActiveAlarmState? {
        guard let data = userDefaults.data(forKey: activeAlarmKey),
              let state = try? JSONDecoder().decode(ActiveAlarmState.self, from: data) else {
            return nil
        }

        // Only return if still active (within 10 minutes)
        let elapsed = Date().timeIntervalSince1970 - state.startTimestamp
        if elapsed < 600 && state.isActive {  // 10 minutes max
            print("📱 Found active alarm state: \(state.alarmID)")
            return state
        }

        print("⏰ Active alarm expired (elapsed: \(Int(elapsed))s)")
        return nil
    }

    /// Clear active alarm state
    func clearActiveAlarm() {
        userDefaults.removeObject(forKey: activeAlarmKey)
        userDefaults.synchronize()
        print("🗑️ Cleared active alarm state")
    }

    /// Check if there's an active alarm that needs to be resumed
    func hasActiveAlarm() -> Bool {
        return getActiveAlarm() != nil
    }
}
