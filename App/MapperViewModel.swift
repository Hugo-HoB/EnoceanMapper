//
//  MapperViewModel.swift
//  EnoceanMapper
//
//  Main view model for device mapping
//

import Foundation
import SwiftUI

class MapperViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var devices: [EnOceanDevice] = []
    @Published var packets: [EnOceanPacket] = []
    @Published var state: ListeningState = .idle
    @Published var statusMessage: String = "Ready to scan"
    @Published var packetCount: Int = 0

    // MARK: - Private Properties

    private let serialManager = SerialPortManager()
    private let parser = ESP3Parser()

    // MARK: - Initialization

    init() {
        setupSerialManager()
    }

    // MARK: - Setup

    private func setupSerialManager() {
        serialManager.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
    }

    // MARK: - Public Methods

    func startListening() {
        guard !state.isListening else { return }

        // Reset data
        devices.removeAll()
        packets.removeAll()
        packetCount = 0
        parser.reset()

        // Connect to serial port
        serialManager.connect()

        if serialManager.isConnected {
            state = .listening
            statusMessage = "Listening for EnOcean devices..."
        } else {
            state = .error(serialManager.connectionError ?? "Unknown error")
            statusMessage = "Error: \(serialManager.connectionError ?? "Unknown error")"
        }
    }

    func stopListening() {
        serialManager.disconnect()
        state = .idle
        statusMessage = "Stopped. Found \(devices.count) devices, \(packets.count) packets."
    }

    // MARK: - Data Handling

    private func handleReceivedData(_ data: Data) {
        // Append to parser
        parser.append(data: data)

        // Parse all available packets
        while true {
            do {
                guard let packet = try parser.parsePacket() else {
                    break
                }

                processPacket(packet)

            } catch ESP3Parser.ParseError.insufficientData {
                // Need more data
                break
            } catch {
                // Error parsing, continue
                print("Parse error: \(error)")
                break
            }
        }
    }

    private func processPacket(_ packet: ESP3Packet) {
        // Only process radio telegrams (ERP1)
        guard packet.packetType == .radioERP1 else {
            return
        }

        guard let telegram = ESP3RadioTelegram(packet: packet) else {
            return
        }

        // Create packet record
        let packetRecord = EnOceanPacket(telegram: telegram)
        packets.append(packetRecord)
        packetCount = packets.count

        // Update or add device
        updateDevice(from: telegram)

        // Update status
        statusMessage = "Listening... \(devices.count) devices, \(packets.count) packets"
    }

    private func updateDevice(from telegram: ESP3RadioTelegram) {
        let deviceId = telegram.senderIdString

        if let index = devices.firstIndex(where: { $0.id == deviceId }) {
            // Update existing device
            devices[index].update(timestamp: Date(), rssi: telegram.signalStrength)
        } else {
            // Add new device
            let newDevice = EnOceanDevice(
                id: deviceId,
                timestamp: Date(),
                rssi: telegram.signalStrength,
                rorg: telegram.rorg
            )
            devices.append(newDevice)
        }
    }

    // MARK: - Export

    func exportDevicesCSV() -> String {
        return CSVExporter.exportDevices(devices)
    }

    func exportPacketsCSV() -> String {
        return CSVExporter.exportPackets(packets)
    }

    func exportCombinedCSV() -> String {
        return CSVExporter.exportCombined(devices: devices, packets: packets)
    }

    // MARK: - Clear Data

    func clearData() {
        devices.removeAll()
        packets.removeAll()
        packetCount = 0
        statusMessage = "Data cleared"
    }
}
