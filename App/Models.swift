//
//  Models.swift
//  EnoceanMapper
//
//  Data models for device mapping
//

import Foundation

// MARK: - EnOcean Device

struct EnOceanDevice: Identifiable, Hashable {
    let id: String  // Device ID (hex string)
    var firstSeen: Date
    var lastSeen: Date
    var packetCount: Int
    var bestRSSI: Int
    var worstRSSI: Int
    var rorg: UInt8
    var deviceType: String

    init(id: String, timestamp: Date, rssi: Int, rorg: UInt8) {
        self.id = id
        self.firstSeen = timestamp
        self.lastSeen = timestamp
        self.packetCount = 1
        self.bestRSSI = rssi
        self.worstRSSI = rssi
        self.rorg = rorg
        self.deviceType = EnOceanDevice.deviceTypeFromRORG(rorg)
    }

    mutating func update(timestamp: Date, rssi: Int) {
        self.lastSeen = timestamp
        self.packetCount += 1
        self.bestRSSI = max(self.bestRSSI, rssi)
        self.worstRSSI = min(self.worstRSSI, rssi)
    }

    static func deviceTypeFromRORG(_ rorg: UInt8) -> String {
        switch rorg {
        case 0xF6: return "Switch (RPS)"
        case 0xD5: return "Contact (1BS)"
        case 0xA5: return "Sensor (4BS)"
        case 0xD2: return "VLD"
        case 0xD1: return "MSC"
        case 0xA6: return "ADT"
        case 0xD4: return "UTE"
        default: return "Unknown"
        }
    }

    var averageRSSI: Int {
        return (bestRSSI + worstRSSI) / 2
    }
}

// MARK: - EnOcean Packet

struct EnOceanPacket: Identifiable {
    let id: UUID
    let timestamp: Date
    let deviceId: String
    let rorg: UInt8
    let rssi: Int
    let payload: Data
    let status: UInt8
    let subTelNum: UInt8

    init(telegram: ESP3RadioTelegram, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.deviceId = telegram.senderIdString
        self.rorg = telegram.rorg
        self.rssi = telegram.signalStrength
        self.payload = telegram.payload
        self.status = telegram.status
        self.subTelNum = telegram.subTelNum
    }

    var payloadHex: String {
        return payload.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    var deviceType: String {
        return EnOceanDevice.deviceTypeFromRORG(rorg)
    }

    var statusBinary: String {
        return String(status, radix: 2).leftPadding(toLength: 8, withPad: "0")
    }
}

// MARK: - Listening State

enum ListeningState {
    case idle
    case listening
    case error(String)

    var isListening: Bool {
        if case .listening = self {
            return true
        }
        return false
    }
}

// MARK: - Helper Extensions

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return self
        }
    }
}

// MARK: - CSV Export

struct CSVExporter {

    static func exportDevices(_ devices: [EnOceanDevice]) -> String {
        var csv = "Device ID,Device Type,RORG,First Seen,Last Seen,Packet Count,Best RSSI,Worst RSSI,Average RSSI\n"

        let dateFormatter = ISO8601DateFormatter()

        for device in devices.sorted(by: { $0.firstSeen < $1.firstSeen }) {
            csv += "\(device.id),"
            csv += "\"\(device.deviceType)\","
            csv += String(format: "0x%02X,", device.rorg)
            csv += "\(dateFormatter.string(from: device.firstSeen)),"
            csv += "\(dateFormatter.string(from: device.lastSeen)),"
            csv += "\(device.packetCount),"
            csv += "\(device.bestRSSI),"
            csv += "\(device.worstRSSI),"
            csv += "\(device.averageRSSI)\n"
        }

        return csv
    }

    static func exportPackets(_ packets: [EnOceanPacket]) -> String {
        var csv = "Timestamp,Device ID,Device Type,RORG,RSSI,Payload (Hex),Status (Binary),SubTel#\n"

        let dateFormatter = ISO8601DateFormatter()

        for packet in packets.sorted(by: { $0.timestamp < $1.timestamp }) {
            csv += "\(dateFormatter.string(from: packet.timestamp)),"
            csv += "\(packet.deviceId),"
            csv += "\"\(packet.deviceType)\","
            csv += String(format: "0x%02X,", packet.rorg)
            csv += "\(packet.rssi),"
            csv += "\"\(packet.payloadHex)\","
            csv += "\(packet.statusBinary),"
            csv += "\(packet.subTelNum)\n"
        }

        return csv
    }

    static func exportCombined(devices: [EnOceanDevice], packets: [EnOceanPacket]) -> String {
        var csv = "=== DEVICES ===\n"
        csv += exportDevices(devices)
        csv += "\n=== PACKETS ===\n"
        csv += exportPackets(packets)
        return csv
    }
}
