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
    @State private var showAlarmRinging = false
    @State private var currentAlertingAlarm: (UUID, WakyAlarmData)?
    @State private var showAuthorizationAlert = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Main app content
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
            checkAuthorizationStatus()
            // Delay NFC check to ensure app is fully in foreground
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkForAlertingAlarms()
            }
        }
        .onChange(of: viewModel.alertingAlarms.count) {
            // Delay NFC check to ensure app is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkForAlertingAlarms()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // App came to foreground - fetch alarms and check for alerting ones
                print("App became active - fetching alarms")
                viewModel.fetchAlarms()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkForAlertingAlarms()
                }
            }
        }

            // Alarm ringing screen (full screen overlay)
            if showAlarmRinging {
                AlarmRingingView(
                    isScanning: showNFCScanning,
                    onScanNFC: {
                        if let (alarmID, metadata) = currentAlertingAlarm {
                            showNFCScanning = true
                            startNFCScan(alarmID: alarmID, expectedTagID: metadata.nfcTagID)
                        }
                    },
                    nfcReader: nfcReader
                )
                .transition(.move(edge: .bottom))
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
        print("🔍 Checking for alerting alarms: count = \(alerting.count)")
        print("🔍 showAlarmRinging = \(showAlarmRinging)")

        if !alerting.isEmpty {
            print("✅ Found \(alerting.count) alerting alarm(s)")
            if let (alarmID, alarm, metadata) = alerting.first {
                print("🚨 Alarm is alerting: \(alarmID)")
                print("🚨 Alarm state: \(alarm.state)")
                print("🚨 Expected NFC tag: \(metadata.nfcTagID)")

                // Store current alerting alarm and show the ringing screen
                currentAlertingAlarm = (alarmID, metadata)
                withAnimation {
                    showAlarmRinging = true
                }
            }
        } else {
            print("⏸️ No alerting alarms found")
            // DON'T hide the screen immediately - persistent alarm will ring in 3 seconds
            // Only hide if user successfully scanned NFC (handled in startNFCScan)
            // Keep the screen visible during the gap between persistent alarms
            print("⏳ Keeping alarm screen visible - waiting for persistent alarm...")
        }
    }

    func startNFCScan(alarmID: UUID, expectedTagID: String) {
        print("📱 Starting NFC scan session...")
        nfcReader.startScanning(expectedTagID: expectedTagID) { success in
            if success {
                print("✅ NFC scan successful! Stopping ALL alarms and hiding screen.")
                viewModel.stopAlarmWithNFC(alarmID: alarmID)

                // Wait a bit then hide the alarm screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showNFCScanning = false
                        showAlarmRinging = false
                        currentAlertingAlarm = nil
                    }
                    print("🎉 Alarm screen hidden - all alarms stopped!")
                }
            } else {
                print("❌ NFC scan failed - keeping screen visible")
                showNFCScanning = false
                // Keep alarm ringing screen visible
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

// Alarm Ringing Screen - Shows when alarm is alerting
struct AlarmRingingView: View {
    var isScanning: Bool
    var onScanNFC: () -> Void
    @Bindable var nfcReader: NFCReader
    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.red.opacity(0.9), Color.orange.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Audio waveform animation
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white)
                            .frame(width: 8, height: waveHeight(for: index))
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: animationAmount
                            )
                    }
                }
                .frame(height: 100)
                .onAppear {
                    animationAmount = 2.0
                }

                // Alarm message
                VStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)

                    Text("Alarm Ringing!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Scan your NFC tag to stop")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // NFC scanning interface or button
                if isScanning {
                    // Show NFC scanning UI
                    VStack(spacing: 24) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating)

                        Text("Hold your iPhone near the NFC tag")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if nfcReader.isScanning {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }

                        if let error = nfcReader.errorMessage {
                            Text(error)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                } else {
                    // Show "Scan NFC" button
                    Button(action: onScanNFC) {
                        HStack(spacing: 12) {
                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                .font(.title2)
                            Text("Scan NFC to Stop Alarm")
                                .font(.title2.bold())
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    }
                    .scaleEffect(animationAmount / 2)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animationAmount)
                }

                Spacer()
            }
            .padding(40)
        }
    }

    private func waveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 100
        let heights: [CGFloat] = [0.3, 0.7, 1.0, 0.7, 0.3]
        return baseHeight + (maxHeight - baseHeight) * heights[index] * (animationAmount / 2)
    }
}

#Preview {
    ContentView()
}
