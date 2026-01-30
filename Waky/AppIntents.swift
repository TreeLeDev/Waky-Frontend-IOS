//
//  AppIntents.swift
//  Waky
//
//  App intents for managing alarms with NFC verification
//

import AlarmKit
import AppIntents
import SwiftUI

// Intent that opens the app for NFC scanning
// When Stop is tapped, this reschedules the alarm to ring again in 3 seconds
// Creating a "persistent alarm" that keeps coming back until NFC is scanned
struct NFCStopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // Schedule a new alarm to ring in 3 seconds (alarm will "restart")
        let threeSecondsFromNow = Date.now.addingTimeInterval(3)
        let time = Alarm.Schedule.Relative.Time(
            hour: Calendar.current.component(.hour, from: threeSecondsFromNow),
            minute: Calendar.current.component(.minute, from: threeSecondsFromNow)
        )
        let schedule = Alarm.Schedule.relative(.init(time: time))

        let alertContent = AlarmPresentation.Alert(title: "Scan NFC to Stop!")
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alertContent),
            metadata: WakyAlarmData(nfcTagID: nfcTagID),
            tintColor: .red  // Red to indicate persistent alarm
        )

        let newID = UUID()
        let alarmConfiguration = AlarmManager.AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: NFCStopIntent(alarmID: newID.uuidString, nfcTagID: nfcTagID)
        )

        // Schedule the new alarm (keeps alarm ringing)
        Task {
            _ = try? await AlarmManager.shared.schedule(id: newID, configuration: alarmConfiguration)
        }

        return .result()
    }

    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Opens app for NFC verification (alarm continues)")
    static var openAppWhenRun = true

    @Parameter(title: "alarmID")
    var alarmID: String

    @Parameter(title: "nfcTagID")
    var nfcTagID: String

    init(alarmID: String, nfcTagID: String) {
        self.alarmID = alarmID
        self.nfcTagID = nfcTagID
    }

    init() {
        self.alarmID = ""
        self.nfcTagID = ""
    }
}

// Fallback stop intent (in case user wants to dismiss without NFC during testing)
// In production, you might want to remove this to enforce NFC-only dismissal
struct ForceStopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        try AlarmManager.shared.stop(id: UUID(uuidString: alarmID)!)
        return .result()
    }

    static var title: LocalizedStringResource = "Force Stop"
    static var description = IntentDescription("Force stop an alarm (testing only)")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}
