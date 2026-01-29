//
//  AlarmMetadata.swift
//  Waky
//
//  Custom metadata structure for Waky alarms with NFC tag ID
//

import AlarmKit

struct WakyAlarmData: AlarmMetadata {
    let createdAt: Date
    let nfcTagID: String

    init(nfcTagID: String = "0455B45F396180") {
        self.createdAt = Date.now
        self.nfcTagID = nfcTagID
    }
}
