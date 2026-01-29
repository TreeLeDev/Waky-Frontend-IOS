//
//  NFCReader.swift
//  Waky
//
//  NFC tag reader for alarm dismissal verification
//

import CoreNFC
import SwiftUI

@Observable class NFCReader: NSObject, NFCTagReaderSessionDelegate {
    var isScanning = false
    var scannedTagID: String?
    var errorMessage: String?
    var onTagScanned: ((String) -> Void)?

    private var session: NFCTagReaderSession?

    func startScanning(expectedTagID: String, completion: @escaping (Bool) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            completion(false)
            return
        }

        isScanning = true
        errorMessage = nil
        scannedTagID = nil

        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self)
        session?.alertMessage = "Hold your iPhone near the NFC tag to stop the alarm"

        onTagScanned = { [weak self] tagID in
            if tagID.uppercased() == expectedTagID.uppercased() {
                self?.session?.alertMessage = "Alarm stopped!"
                self?.session?.invalidate()
                completion(true)
            } else {
                self?.errorMessage = "Wrong NFC tag! Expected: \(expectedTagID), Got: \(tagID)"
                self?.session?.invalidate(errorMessage: "Wrong NFC tag. Please use the correct tag.")
                completion(false)
            }
        }

        session?.begin()
    }

    func stopScanning() {
        session?.invalidate()
        isScanning = false
    }

    // MARK: - NFCTagReaderSessionDelegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session is now active
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            // Get tag identifier based on tag type
            var tagID = ""

            switch tag {
            case .iso7816(let iso7816Tag):
                tagID = iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined()
            case .feliCa(let feliCaTag):
                tagID = feliCaTag.currentIDm.map { String(format: "%02X", $0) }.joined()
            case .miFare(let miFareTag):
                tagID = miFareTag.identifier.map { String(format: "%02X", $0) }.joined()
            case .iso15693(let iso15693Tag):
                tagID = iso15693Tag.identifier.map { String(format: "%02X", $0) }.joined()
            @unknown default:
                tagID = ""
            }

            DispatchQueue.main.async {
                self.scannedTagID = tagID
                self.onTagScanned?(tagID)
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    self.errorMessage = "NFC scan was cancelled"
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "NFC scan timed out"
                default:
                    self.errorMessage = "NFC error: \(error.localizedDescription)"
                }
            }
        }
    }
}
