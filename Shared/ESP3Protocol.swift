//
//  ESP3Protocol.swift
//  EnoceanMapper
//
//  EnOcean Serial Protocol 3 (ESP3) Implementation
//  Based on: https://www.enocean.com/wp-content/uploads/Knowledge-Base/EnOceanSerialProtocol3-1.pdf
//

import Foundation

// MARK: - ESP3 Constants

enum ESP3Constants {
    static let syncByte: UInt8 = 0x55
    static let maxDataLength: UInt16 = 21
    static let headerSize = 4
    static let crcSize = 1
}

// MARK: - ESP3 Packet Types

enum ESP3PacketType: UInt8 {
    case radioERP1 = 0x01           // Radio telegram
    case response = 0x02            // Response to a command
    case radioSubTel = 0x03         // Radio subtelegram
    case event = 0x04               // Event message
    case commonCommand = 0x05       // Common command
    case smartAckCommand = 0x06     // Smart Ack command
    case remoteManCommand = 0x07    // Remote management command
    case radioMessage = 0x09        // Radio message
    case radioERP2 = 0x0A           // ERP2 protocol radio telegram
    case radio802_15_4 = 0x10       // 802.15.4_RAW Packet
    case command2_4 = 0x11          // 2.4 GHz Command
}

// MARK: - ESP3 Return Codes

enum ESP3ReturnCode: UInt8 {
    case ok = 0x00
    case error = 0x01
    case notSupported = 0x02
    case wrongParam = 0x03
    case operationDenied = 0x04
    case lockSet = 0x05
    case bufferTooSmall = 0x06
    case noFreeBuffer = 0x07
}

// MARK: - ESP3 Common Commands

enum ESP3CommonCommand: UInt8 {
    case coWrSleep = 0x01           // Order to enter in energy saving mode
    case coWrReset = 0x02           // Order to reset the device
    case coRdVersion = 0x03         // Read the device version information
    case coRdSysLog = 0x04          // Read system log
    case coWrSysLog = 0x05          // Reset system log
    case coWrBist = 0x06            // Perform built in self test
    case coWrIdBase = 0x07          // Write ID range base address
    case coRdIdBase = 0x08          // Read ID range base address
    case coWrRepeater = 0x09        // Write repeater level
    case coRdRepeater = 0x0A        // Read repeater level
    case coWrFilterAdd = 0x0B       // Add filter to filter list
    case coWrFilterDel = 0x0C       // Delete filter from filter list
    case coWrFilterDelAll = 0x0D    // Delete all filters
    case coWrFilterEnable = 0x0E    // Enable/disable filter list
    case coRdFilter = 0x0F          // Read filter list
    case coWrWaitMaturity = 0x10    // Wait until the end of maturity time
    case coWrSubtel = 0x11          // Enable/disable subtelegram
    case coWrMem = 0x12             // Write memory
    case coRdMem = 0x13             // Read memory
    case coRdMemAddress = 0x14      // Read memory address
    case coRdSecurity = 0x15        // Read security information
    case coWrSecurity = 0x16        // Write security information
}

// MARK: - ESP3 Packet Structure

struct ESP3Packet {
    let packetType: ESP3PacketType
    let data: Data
    let optionalData: Data

    var dataLength: UInt16 {
        return UInt16(data.count)
    }

    var optionalLength: UInt8 {
        return UInt8(optionalData.count)
    }

    // MARK: - Serialization

    func serialize() -> Data {
        var packet = Data()

        // Sync byte
        packet.append(ESP3Constants.syncByte)

        // Header: Data Length (2 bytes), Optional Length (1 byte), Packet Type (1 byte)
        let dataLen = dataLength
        packet.append(UInt8(dataLen >> 8))      // Data length MSB
        packet.append(UInt8(dataLen & 0xFF))    // Data length LSB
        packet.append(optionalLength)           // Optional length
        packet.append(packetType.rawValue)      // Packet type

        // Header CRC8
        let headerCRC = CRC8.calculate(data: packet.suffix(from: 1))
        packet.append(headerCRC)

        // Data + Optional Data
        packet.append(data)
        packet.append(optionalData)

        // Data CRC8
        let dataCRC = CRC8.calculate(data: packet.suffix(from: 6))
        packet.append(dataCRC)

        return packet
    }
}

// MARK: - ESP3 Parser

class ESP3Parser {
    private var buffer = Data()

    enum ParseError: Error {
        case insufficientData
        case invalidSyncByte
        case headerCRCMismatch
        case dataCRCMismatch
        case invalidPacketType
        case bufferOverflow
    }

    // MARK: - Public Methods

    func append(data: Data) {
        buffer.append(data)

        // Prevent buffer overflow
        if buffer.count > 1024 {
            // Keep only the last 512 bytes if buffer grows too large
            buffer = buffer.suffix(512)
        }
    }

    func parsePacket() throws -> ESP3Packet? {
        // Need at least 6 bytes for minimal packet (header + CRCs)
        guard buffer.count >= 6 else {
            throw ParseError.insufficientData
        }

        // Find sync byte
        guard let syncIndex = buffer.firstIndex(of: ESP3Constants.syncByte) else {
            // No sync byte found, clear buffer
            buffer.removeAll()
            throw ParseError.invalidSyncByte
        }

        // Remove data before sync byte
        if syncIndex > 0 {
            buffer.removeSubrange(0..<syncIndex)
        }

        // Check if we have enough data for header
        guard buffer.count >= 6 else {
            throw ParseError.insufficientData
        }

        // Parse header
        let dataLength = (UInt16(buffer[1]) << 8) | UInt16(buffer[2])
        let optionalLength = buffer[3]
        let packetTypeRaw = buffer[4]
        let headerCRC = buffer[5]

        // Validate header CRC
        let calculatedHeaderCRC = CRC8.calculate(data: buffer[1..<5])
        guard headerCRC == calculatedHeaderCRC else {
            // Invalid CRC, remove sync byte and try again
            buffer.removeFirst()
            throw ParseError.headerCRCMismatch
        }

        // Validate packet type
        guard let packetType = ESP3PacketType(rawValue: packetTypeRaw) else {
            buffer.removeFirst()
            throw ParseError.invalidPacketType
        }

        // Calculate total packet size
        let totalDataSize = Int(dataLength) + Int(optionalLength)
        let packetSize = 6 + totalDataSize + 1  // header(4) + header_crc(1) + sync(1) + data + optional + data_crc(1)

        // Check if we have the complete packet
        guard buffer.count >= packetSize else {
            throw ParseError.insufficientData
        }

        // Extract data and optional data
        let dataStart = 6
        let dataEnd = dataStart + Int(dataLength)
        let optionalEnd = dataEnd + Int(optionalLength)

        let data = buffer[dataStart..<dataEnd]
        let optionalData = buffer[dataEnd..<optionalEnd]

        // Validate data CRC
        let dataCRC = buffer[optionalEnd]
        let calculatedDataCRC = CRC8.calculate(data: buffer[dataStart..<optionalEnd])
        guard dataCRC == calculatedDataCRC else {
            buffer.removeFirst()
            throw ParseError.dataCRCMismatch
        }

        // Remove parsed packet from buffer
        buffer.removeSubrange(0..<packetSize)

        return ESP3Packet(
            packetType: packetType,
            data: Data(data),
            optionalData: Data(optionalData)
        )
    }

    func reset() {
        buffer.removeAll()
    }
}

// MARK: - CRC8 Calculator

struct CRC8 {
    private static let polynomial: UInt8 = 0x07

    static func calculate(data: Data) -> UInt8 {
        var crc: UInt8 = 0

        for byte in data {
            crc ^= byte
            for _ in 0..<8 {
                if (crc & 0x80) != 0 {
                    crc = (crc << 1) ^ polynomial
                } else {
                    crc <<= 1
                }
            }
        }

        return crc
    }
}

// MARK: - ESP3 Radio Telegram (ERP1)

struct ESP3RadioTelegram {
    let rorg: UInt8             // R-ORG (Radio Telegram Type)
    let payload: Data           // Actual data
    let senderId: UInt32        // Sender ID (4 bytes)
    let status: UInt8           // Status byte
    let subTelNum: UInt8        // Sub-telegram number
    let destinationId: UInt32   // Destination ID (optional data)
    let dBm: Int8               // Receive signal strength
    let securityLevel: UInt8    // Security level

    init?(packet: ESP3Packet) {
        guard packet.packetType == .radioERP1 else { return nil }
        guard packet.data.count >= 6 else { return nil }  // Minimum: RORG + 4-byte data + status

        self.rorg = packet.data[0]

        // Data length varies, but last 5 bytes are always: sender ID (4 bytes) + status (1 byte)
        let dataLength = packet.data.count - 5
        guard dataLength >= 0 else { return nil }

        self.payload = packet.data[1..<(1 + dataLength)]

        let senderIdStart = 1 + dataLength
        self.senderId = (UInt32(packet.data[senderIdStart]) << 24) |
                       (UInt32(packet.data[senderIdStart + 1]) << 16) |
                       (UInt32(packet.data[senderIdStart + 2]) << 8) |
                       UInt32(packet.data[senderIdStart + 3])

        self.status = packet.data[senderIdStart + 4]

        // Optional data
        if packet.optionalData.count >= 7 {
            self.subTelNum = packet.optionalData[0]

            self.destinationId = (UInt32(packet.optionalData[1]) << 24) |
                                (UInt32(packet.optionalData[2]) << 16) |
                                (UInt32(packet.optionalData[3]) << 8) |
                                UInt32(packet.optionalData[4])

            self.dBm = Int8(bitPattern: packet.optionalData[5])
            self.securityLevel = packet.optionalData[6]
        } else {
            self.subTelNum = 0
            self.destinationId = 0
            self.dBm = 0
            self.securityLevel = 0
        }
    }

    var senderIdString: String {
        return String(format: "%08X", senderId)
    }

    var signalStrength: Int {
        return Int(dBm)
    }
}

// MARK: - Common R-ORG Types

enum EnoceanRORG: UInt8 {
    case rps = 0xF6         // Repeated Switch Communication
    case bs1 = 0xD5         // 1 Byte Communication
    case bs4 = 0xA5         // 4 Byte Communication
    case vld = 0xD2         // Variable Length Data
    case msc = 0xD1         // Manufacturer Specific Communication
    case adt = 0xA6         // Addressing Destination Telegram
    case sm_lRN_TEL = 0xC6  // Smart Acknowledge Learn Request
    case sm_REC = 0xA7      // Smart Acknowledge Signal Telegram
    case sys_ex = 0xC5      // Remote Management
    case sec = 0x30         // Secure telegram
    case sec_encaps = 0x31  // Secure telegram with encapsulation
    case ute = 0xD4         // Universal Teach-In EEP based
}
