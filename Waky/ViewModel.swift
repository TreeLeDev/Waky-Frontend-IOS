//
//  ViewModel.swift
//  Waky
//
//  Observable view model for managing alarms and NFC scanning
//

import AlarmKit
import SwiftUI
import AppIntents

@Observable class ViewModel {
    typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<WakyAlarmData>
    typealias AlarmsMap = [UUID: (Alarm, LocalizedStringResource, WakyAlarmData)]

    @MainActor var alarmsMap = AlarmsMap()
    @ObservationIgnored private let alarmManager = AlarmManager.shared

    @MainActor var hasUpcomingAlerts: Bool {
        !alarmsMap.isEmpty
    }

    @MainActor var alertingAlarms: [(UUID, Alarm, WakyAlarmData)] {
        alarmsMap.compactMap { id, value in
            let (alarm, _, metadata) = value
            if alarm.state == .alerting {
                return (id, alarm, metadata)
            }
            return nil
        }
    }

    init() {
        observeAlarms()
    }

    func fetchAlarms() {
        do {
            let remoteAlarms = try alarmManager.alarms
            updateAlarmState(with: remoteAlarms)
        } catch {
            print("Error fetching alarms: \(error)")
        }
    }

    // Quick test alarm - triggers in 2 minutes (matches example pattern)
    func scheduleTestAlarm() {
        print("=== SCHEDULING TEST ALARM ===")
        let twoMinsFromNow = Date.now.addingTimeInterval(2 * 60)
        let time = Alarm.Schedule.Relative.Time(
            hour: Calendar.current.component(.hour, from: twoMinsFromNow),
            minute: Calendar.current.component(.minute, from: twoMinsFromNow)
        )
        let schedule = Alarm.Schedule.relative(.init(time: time))
        print("Test alarm schedule: \(schedule)")

        // System stop button will trigger NFCStopIntent (opens app, doesn't stop alarm)
        let alertContent = AlarmPresentation.Alert(title: "Test Alarm")

        let metadata = WakyAlarmData()
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alertContent),
            metadata: metadata,
            tintColor: Color.orange
        )

        let id = UUID()
        print("Test alarm ID: \(id)")

        let alarmConfiguration = AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: NFCStopIntent(alarmID: id.uuidString, nfcTagID: "0455B45F396180")
        )

        scheduleAlarm(id: id, label: "Test Alarm", metadata: metadata, alarmConfiguration: alarmConfiguration)
    }

    func scheduleAlarm(with userInput: AlarmForm, nfcTagID: String = "0455B45F396180") {
        print("=== SCHEDULING ALARM ===")
        print("Label: \(userInput.label)")
        print("Selected date: \(userInput.selectedDate)")
        print("Selected days: \(userInput.selectedDays)")

        let metadata = WakyAlarmData(nfcTagID: nfcTagID)
        let attributes = AlarmAttributes(
            presentation: alarmPresentation(with: userInput),
            metadata: metadata,
            tintColor: Color.orange
        )

        let id = UUID()
        print("Alarm ID: \(id)")

        guard let schedule = userInput.schedule else {
            print("❌ ERROR: Invalid schedule - userInput.schedule is nil")
            return
        }

        print("✅ Schedule created: \(schedule)")

        let alarmConfiguration = AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: NFCStopIntent(alarmID: id.uuidString, nfcTagID: nfcTagID),
            secondaryIntent: NFCStopIntent(alarmID: id.uuidString, nfcTagID: nfcTagID)
        )

        print("Calling scheduleAlarm with ID: \(id)")
        scheduleAlarm(id: id, label: userInput.localizedLabel, metadata: metadata, alarmConfiguration: alarmConfiguration)
    }

    func unscheduleAlarm(with alarmID: UUID) {
        try? alarmManager.cancel(id: alarmID)
        Task { @MainActor in
            alarmsMap[alarmID] = nil
        }
    }

    func stopAlarmWithNFC(alarmID: UUID) {
        do {
            // Stop the current alarm
            try alarmManager.stop(id: alarmID)
            print("Alarm \(alarmID) stopped successfully")

            // CRITICAL: Stop ALL alerting alarms to prevent persistent alarm from rescheduling
            let allAlarms = try? alarmManager.alarms
            allAlarms?.forEach { alarm in
                if alarm.state == .alerting || alarm.state == .scheduled {
                    try? alarmManager.cancel(id: alarm.id)
                    print("Cancelled persistent alarm: \(alarm.id)")
                }
            }
        } catch {
            print("Error stopping alarm: \(error)")
        }
    }

    private func scheduleAlarm(id: UUID, label: LocalizedStringResource, metadata: WakyAlarmData, alarmConfiguration: AlarmConfiguration) {
        print("📝 scheduleAlarm called with ID: \(id)")
        Task {
            do {
                print("🔐 Requesting authorization...")
                let authorized = await requestAuthorization()
                print("Authorization result: \(authorized)")

                guard authorized else {
                    print("❌ Not authorized to schedule alarms.")
                    return
                }

                print("✅ Authorized! Scheduling alarm...")
                let alarm = try await alarmManager.schedule(id: id, configuration: alarmConfiguration)
                print("✅ Alarm scheduled successfully: \(alarm)")
                print("Alarm state: \(alarm.state)")
                print("Alarm schedule: \(String(describing: alarm.schedule))")

                await MainActor.run {
                    print("📍 Adding alarm to alarmsMap on MainActor")
                    alarmsMap[id] = (alarm, label, metadata)
                    print("📍 alarmsMap now has \(alarmsMap.count) alarms")
                }
            } catch {
                print("❌ ERROR encountered when scheduling alarm: \(error)")
                print("Error localized: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain)")
                    print("Error code: \(nsError.code)")
                    print("Error userInfo: \(nsError.userInfo)")
                }
            }
        }
    }

    private func alarmPresentation(with userInput: AlarmForm) -> AlarmPresentation {
        // iOS 26.1+ uses system stop button, but we control behavior via stopIntent
        // When user taps "Stop", NFCStopIntent opens app without stopping alarm
        // Alarm only stops after successful NFC scan
        let alertContent = AlarmPresentation.Alert(title: userInput.localizedLabel)
        return AlarmPresentation(alert: alertContent)
    }

    private func observeAlarms() {
        Task {
            for await incomingAlarms in alarmManager.alarmUpdates {
                updateAlarmState(with: incomingAlarms)
            }
        }
    }

    private func updateAlarmState(with remoteAlarms: [Alarm]) {
        Task { @MainActor in
            // Update existing alarm states
            remoteAlarms.forEach { updated in
                if let existing = alarmsMap[updated.id] {
                    alarmsMap[updated.id] = (updated, existing.1, existing.2)
                } else {
                    // New alarm from persistent alarm - use default NFC tag
                    let metadata = WakyAlarmData(nfcTagID: "0455B45F396180")
                    alarmsMap[updated.id] = (updated, "Scan NFC to Stop!", metadata)
                    print("Added persistent alarm to map: \(updated.id)")
                }
            }

            let knownAlarmIDs = Set(alarmsMap.keys)
            let incomingAlarmIDs = Set(remoteAlarms.map(\.id))

            // Clean up removed alarms
            let removedAlarmIDs = Set(knownAlarmIDs.subtracting(incomingAlarmIDs))
            removedAlarmIDs.forEach {
                alarmsMap[$0] = nil
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        print("Current authorization state: \(alarmManager.authorizationState)")

        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                print("Requesting AlarmKit authorization...")
                let state = try await alarmManager.requestAuthorization()
                print("Authorization result: \(state)")
                return state == .authorized
            } catch {
                print("Error occurred while requesting authorization: \(error)")
                print("Error details: \(error.localizedDescription)")
                return false
            }
        case .denied:
            print("AlarmKit authorization denied")
            return false
        case .authorized:
            print("AlarmKit already authorized")
            return true
        @unknown default:
            print("Unknown authorization state")
            return false
        }
    }
}

extension Alarm {
    var alertingTime: Date? {
        guard let schedule else { return nil }

        switch schedule {
        case .fixed(let date):
            return date
        case .relative(let relative):
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
            components.hour = relative.time.hour
            components.minute = relative.time.minute
            return Calendar.current.date(from: components)
        @unknown default:
            return nil
        }
    }
}

extension AlarmButton {
    static var stopButton: Self {
        AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
    }

    static var nfcButton: Self {
        AlarmButton(text: "Scan NFC", textColor: .white, systemImageName: "sensor.tag.radiowaves.forward.fill")
    }
}

extension Locale {
    var orderedWeekdays: [Locale.Weekday] {
        let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        if let firstDayIdx = days.firstIndex(of: firstDayOfWeek), firstDayIdx != 0 {
            return Array(days[firstDayIdx...] + days[0..<firstDayIdx])
        }
        return days
    }
}
