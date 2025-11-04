//
//  SerialPortManager.swift
//  EnoceanMapper
//
//  Manages communication with EnOcean USB dongle via DriverKit
//

import Foundation
import IOKit
import IOKit.serial

class SerialPortManager: ObservableObject {

    // MARK: - Properties

    @Published var isConnected = false
    @Published var connectionError: String?

    private var fileDescriptor: Int32 = -1
    private var readThread: Thread?
    private var shouldRead = false

    var onDataReceived: ((Data) -> Void)?

    // MARK: - Connection

    func connect() {
        // Find EnOcean serial port
        guard let portPath = findSerialPort() else {
            connectionError = "No EnOcean device found. Please connect the USB dongle."
            return
        }

        // Open serial port
        fileDescriptor = open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor != -1 else {
            connectionError = "Failed to open serial port: \(String(cString: strerror(errno)))"
            return
        }

        // Configure serial port
        guard configurePort() else {
            close(fileDescriptor)
            fileDescriptor = -1
            connectionError = "Failed to configure serial port"
            return
        }

        isConnected = true
        connectionError = nil

        // Start reading thread
        startReading()
    }

    func disconnect() {
        shouldRead = false

        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        isConnected = false
    }

    // MARK: - Serial Port Discovery

    private func findSerialPort() -> String? {
        let fileManager = FileManager.default

        // Look for common FTDI device paths
        let searchPaths = [
            "/dev/cu.usbserial",
            "/dev/tty.usbserial",
            "/dev/cu.SLAB_USBtoUART",
            "/dev/tty.SLAB_USBtoUART"
        ]

        // Check for exact matches first
        for path in searchPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        // Search /dev directory for FTDI devices
        do {
            let devDirectory = try fileManager.contentsOfDirectory(atPath: "/dev")

            // Look for cu.usbserial* or tty.usbserial* devices
            for file in devDirectory {
                if file.hasPrefix("cu.usbserial") || file.hasPrefix("tty.usbserial") {
                    return "/dev/\(file)"
                }
            }
        } catch {
            print("Error searching /dev directory: \(error)")
        }

        return nil
    }

    // MARK: - Serial Port Configuration

    private func configurePort() -> Bool {
        var options = termios()

        // Get current options
        guard tcgetattr(fileDescriptor, &options) == 0 else {
            return false
        }

        // Set baud rate (57600 for TCM310)
        cfsetispeed(&options, speed_t(B57600))
        cfsetospeed(&options, speed_t(B57600))

        // 8N1 mode
        options.c_cflag |= tcflag_t(CS8)        // 8 data bits
        options.c_cflag &= ~tcflag_t(PARENB)    // No parity
        options.c_cflag &= ~tcflag_t(CSTOPB)    // 1 stop bit

        // Enable receiver, ignore modem control lines
        options.c_cflag |= tcflag_t(CREAD | CLOCAL)

        // Disable hardware flow control
        options.c_cflag &= ~tcflag_t(CRTSCTS)

        // Raw mode
        options.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)

        // Disable software flow control
        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)

        // Raw output
        options.c_oflag &= ~tcflag_t(OPOST)

        // Set read timeout
        options.c_cc.16 = 1  // VMIN = 1 (minimum characters)
        options.c_cc.17 = 10 // VTIME = 1 second timeout

        // Apply settings
        guard tcsetattr(fileDescriptor, TCSANOW, &options) == 0 else {
            return false
        }

        // Flush buffers
        tcflush(fileDescriptor, TCIOFLUSH)

        return true
    }

    // MARK: - Reading

    private func startReading() {
        shouldRead = true

        readThread = Thread { [weak self] in
            guard let self = self else { return }

            var buffer = [UInt8](repeating: 0, count: 1024)

            while self.shouldRead {
                let bytesRead = read(self.fileDescriptor, &buffer, buffer.count)

                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    DispatchQueue.main.async {
                        self.onDataReceived?(data)
                    }
                } else if bytesRead < 0 && errno != EAGAIN {
                    // Error occurred
                    DispatchQueue.main.async {
                        self.connectionError = "Read error: \(String(cString: strerror(errno)))"
                        self.disconnect()
                    }
                    break
                }

                // Small delay to prevent busy waiting
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        readThread?.start()
    }

    // MARK: - Writing

    func write(data: Data) -> Bool {
        guard isConnected, fileDescriptor != -1 else {
            return false
        }

        let bytesWritten = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
            return Darwin.write(fileDescriptor, ptr.baseAddress, data.count)
        }

        return bytesWritten == data.count
    }

    // MARK: - Commands

    func sendCommand(command: ESP3CommonCommand, data: Data = Data()) -> Bool {
        let packet = ESP3Packet(
            packetType: .commonCommand,
            data: Data([command.rawValue]) + data,
            optionalData: Data()
        )

        return write(data: packet.serialize())
    }

    func readVersion() -> Bool {
        return sendCommand(command: .coRdVersion)
    }

    func readBaseID() -> Bool {
        return sendCommand(command: .coRdIdBase)
    }

    // MARK: - Cleanup

    deinit {
        disconnect()
    }
}
