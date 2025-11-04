//
//  EnoceanDriver.swift
//  EnoceanMapper DriverKit Extension
//
//  USB Serial Driver for EnOcean TCM310 (FTDI-based)
//

import Foundation
import DriverKit
import USBDriverKit
import USBSerialDriverKit

class EnoceanDriver: IOUserUSBSerial {

    // FTDI Vendor ID and common Product IDs
    static let ftdiVendorID: UInt16 = 0x0403
    static let ftdiProductID: UInt16 = 0x6001  // FT232 USB-UART

    // Serial configuration for EnOcean TCM310
    static let defaultBaudRate: UInt32 = 57600  // TCM310 default
    static let dataBits: UInt8 = 8
    static let parityType: IOUSBSerialParityType = .none
    static let stopBits: UInt8 = 1

    private var isOpen = false

    // MARK: - Driver Lifecycle

    override func start(provider: IOService) -> kern_return_t {
        let result = super.start(provider: provider)
        guard result == kIOReturnSuccess else {
            return result
        }

        os_log("EnOcean Driver started for FTDI device", log: OSLog.default, type: .info)

        // Configure serial port
        configureSerialPort()

        return kIOReturnSuccess
    }

    override func stop(provider: IOService) -> kern_return_t {
        os_log("EnOcean Driver stopping", log: OSLog.default, type: .info)

        isOpen = false

        return super.stop(provider: provider)
    }

    // MARK: - Serial Configuration

    private func configureSerialPort() {
        // Set baud rate
        _ = SetBaud(EnoceanDriver.defaultBaudRate)

        // Configure data format: 8N1 (8 data bits, no parity, 1 stop bit)
        _ = SetDataBits(EnoceanDriver.dataBits)
        _ = SetParity(EnoceanDriver.parityType)
        _ = SetStopBits(EnoceanDriver.stopBits)

        // Disable hardware flow control (software handshake only)
        _ = SetFlowControl(.none)

        isOpen = true

        os_log("Serial port configured: %d baud, 8N1",
               log: OSLog.default,
               type: .info,
               EnoceanDriver.defaultBaudRate)
    }

    // MARK: - Data Handling

    override func HandleDataReceived(data: IOMemoryDescriptor, length: Int) {
        guard isOpen else { return }

        // Forward received data to user space client
        super.HandleDataReceived(data: data, length: length)

        os_log("Received %d bytes from EnOcean device", log: OSLog.default, type: .debug, length)
    }

    override func HandleDataTransmitted() {
        super.HandleDataTransmitted()
        os_log("Data transmitted to EnOcean device", log: OSLog.default, type: .debug)
    }
}

// MARK: - IOUSBSerial Override

extension EnoceanDriver {

    /// Called when device is matched and attached
    override func deviceWillOpen() -> Bool {
        os_log("EnOcean device will open", log: OSLog.default, type: .info)
        return true
    }

    /// Called when device is closed
    override func deviceDidClose() {
        os_log("EnOcean device closed", log: OSLog.default, type: .info)
        isOpen = false
    }
}

// MARK: - User Client Communication

extension EnoceanDriver {

    /// Handle external method calls from user space app
    override func ExternalMethod(
        selector: UInt32,
        arguments: IOExternalMethodArguments?,
        completion: IOExternalMethodCompletion?
    ) -> kern_return_t {

        os_log("External method called: selector=%d",
               log: OSLog.default,
               type: .debug,
               selector)

        // Forward to superclass for standard handling
        return super.ExternalMethod(
            selector: selector,
            arguments: arguments,
            completion: completion
        )
    }
}
