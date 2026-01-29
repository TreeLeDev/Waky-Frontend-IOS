//
//  AlarmForm.swift
//  Waky
//
//  Form structure containing alarm configuration
//

import AlarmKit

struct AlarmForm {
    var label = ""
    var selectedDate = Date.now
    var selectedDays = Set<Locale.Weekday>()

    var isValidAlarm: Bool {
        !label.isEmpty
    }

    var localizedLabel: LocalizedStringResource {
        label.isEmpty ? LocalizedStringResource("Waky Alarm") : LocalizedStringResource(stringLiteral: label)
    }

    func isSelected(day: Locale.Weekday) -> Bool {
        selectedDays.contains(day)
    }

    // MARK: AlarmKit Properties

    var schedule: Alarm.Schedule? {
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)

        guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return nil }

        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        return .relative(.init(
            time: time,
            repeats: selectedDays.isEmpty ? .never : .weekly(Array(selectedDays))
        ))
    }
}
