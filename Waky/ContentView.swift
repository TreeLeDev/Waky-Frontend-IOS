//
//  ContentView.swift
//  Waky
//
//  Main UI for Waky - NFC-based alarm app
//

import AlarmKit
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var nfcReader = NFCReader()
    @State private var showAddSheet = false
    @State private var showNFCScanning = false
    @State private var showAuthorizationAlert = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Waky")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    addButton
                }
        }
        .sheet(isPresented: $showAddSheet) {
            AlarmAddView()
        }
        .environment(viewModel)
        .onAppear {
            viewModel.fetchAlarms()
            checkForAlertingAlarms()
            checkAuthorizationStatus()
        }
        .onChange(of: viewModel.alertingAlarms.count) {
            checkForAlertingAlarms()
        }
        .overlay {
            if showNFCScanning {
                NFCScanView(nfcReader: nfcReader, onDismiss: {
                    showNFCScanning = false
                })
            }
        }
        .alert("AlarmKit Authorization", isPresented: $showAuthorizationAlert) {
            Button("Open Settings", action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            Button("OK", role: .cancel) {}
        } message: {
            Text("Waky needs permission to schedule alarms. Please grant AlarmKit access in Settings.")
        }
        .tint(.orange)
    }

    func checkAuthorizationStatus() {
        Task {
            let manager = AlarmManager.shared
            print("Checking authorization status: \(manager.authorizationState)")
            if manager.authorizationState == .denied {
                showAuthorizationAlert = true
            }
        }
    }

    var addButton: some View {
        Menu {
            Button {
                showAddSheet.toggle()
            } label: {
                Label("New Alarm", systemImage: "plus.circle")
            }

            Button {
                viewModel.scheduleTestAlarm()
            } label: {
                Label("Test Alarm (2 min)", systemImage: "timer")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
        }
    }

    @ViewBuilder var content: some View {
        if viewModel.hasUpcomingAlerts {
            alarmList(alarms: Array(viewModel.alarmsMap.values))
        } else {
            ContentUnavailableView(
                "No Alarms",
                systemImage: "alarm.fill",
                description: Text("Tap the + button to create your first alarm")
            )
        }
    }

    func alarmList(alarms: [ViewModel.AlarmsMap.Value]) -> some View {
        List {
            ForEach(alarms, id: \.0.id) { (alarm, label, metadata) in
                AlarmCell(alarm: alarm, label: label, nfcTagID: metadata.nfcTagID)
            }
            .onDelete { indexSet in
                indexSet.forEach { idx in
                    viewModel.unscheduleAlarm(with: alarms[idx].0.id)
                }
            }
        }
    }

    func checkForAlertingAlarms() {
        let alerting = viewModel.alertingAlarms
        if !alerting.isEmpty && !showNFCScanning {
            // Automatically prompt NFC scan when alarm is alerting
            if let (alarmID, _, metadata) = alerting.first {
                showNFCScanning = true
                startNFCScan(alarmID: alarmID, expectedTagID: metadata.nfcTagID)
            }
        }
    }

    func startNFCScan(alarmID: UUID, expectedTagID: String) {
        nfcReader.startScanning(expectedTagID: expectedTagID) { success in
            if success {
                viewModel.stopAlarmWithNFC(alarmID: alarmID)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showNFCScanning = false
                }
            }
        }
    }
}

struct AlarmCell: View {
    var alarm: Alarm
    var label: LocalizedStringResource
    var nfcTagID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let alertingTime = alarm.alertingTime {
                    Text(alertingTime, style: .time)
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                } else {
                    Text("--:--")
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                }
                Spacer()
                tag
            }

            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.caption)
                Text("NFC: \(nfcTagID)")
                    .font(.caption)
                    .monospaced()
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    var tag: some View {
        Text(tagLabel)
            .textCase(.uppercase)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tagColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var tagLabel: String {
        switch alarm.state {
        case .scheduled: "Scheduled"
        case .countdown: "Running"
        case .paused: "Paused"
        case .alerting: "Ringing"
        @unknown default: "Unknown"
        }
    }

    var tagColor: Color {
        switch alarm.state {
        case .scheduled: .blue
        case .countdown: .green
        case .paused: .yellow
        case .alerting: .red
        @unknown default: .gray
        }
    }
}

struct AlarmAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ViewModel.self) private var viewModel

    @State private var userInput = AlarmForm()

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm Details") {
                    TextField("Alarm Label", text: $userInput.label)
                        .textInputAutocapitalization(.words)
                }

                Section("Time") {
                    DatePicker("Alarm Time", selection: $userInput.selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("Repeat") {
                    daysOfTheWeekSection
                }

                Section {
                    HStack {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        Text("This alarm requires NFC tag **0455B45F396180** to dismiss")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.scheduleAlarm(with: userInput)
                        dismiss()
                    }
                    .disabled(!userInput.isValidAlarm)
                    .fontWeight(.bold)
                }
            }
        }
    }

    var daysOfTheWeekSection: some View {
        HStack(spacing: 8) {
            ForEach(Locale.autoupdatingCurrent.orderedWeekdays, id: \.self) { weekday in
                Button(action: {
                    if userInput.isSelected(day: weekday) {
                        userInput.selectedDays.remove(weekday)
                    } else {
                        userInput.selectedDays.insert(weekday)
                    }
                }) {
                    Text(weekday.rawValue.prefix(1).uppercased())
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .tint(.orange.opacity(userInput.isSelected(day: weekday) ? 1 : 0.3))
                .buttonBorderShape(.circle)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct NFCScanView: View {
    @Bindable var nfcReader: NFCReader
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                    .symbolEffect(.variableColor.iterative, options: .repeating)

                VStack(spacing: 10) {
                    Text("Scan NFC Tag to Stop Alarm")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Hold your iPhone near the NFC tag")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if let error = nfcReader.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }

                if nfcReader.isScanning {
                    ProgressView()
                        .tint(.orange)
                        .scaleEffect(1.5)
                }

                Button("Cancel") {
                    nfcReader.stopScanning()
                    onDismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(10)
            }
            .padding(40)
        }
    }
}

#Preview {
    ContentView()
}
