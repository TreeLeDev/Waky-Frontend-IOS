//
//  AppIntents.swift
//  Waky
//
//  App intents for managing alarms with NFC verification
//

import AlarmKit
import AppIntents

// Intent that opens the app for NFC scanning (does not stop alarm until NFC is scanned)
struct NFCStopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // This intent opens the app but does NOT stop the alarm
        // The alarm will only be stopped after successful NFC scan in the app
        return .result()
    }

    static var title: LocalizedStringResource = "Scan NFC to Stop"
    static var description = IntentDescription("Opens the app to scan NFC tag for alarm dismissal")
    static var openAppWhenRun = true  // This is the key - it opens the app

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
