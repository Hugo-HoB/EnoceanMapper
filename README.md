# EnOcean Mapper for iPad

A professional iPad application for mapping and analyzing EnOcean wireless devices using a USB TCM310 dongle. Features a modern spreadsheet-style UI for real-time device discovery, packet analysis, and CSV export capabilities.

## Features

- **Real-time Device Discovery**: Automatically detect and list all EnOcean devices within range
- **Packet Analysis**: Capture and display all EnOcean packets with RSSI, payload, and status information
- **Spreadsheet UI**: Clean, tabular interface inspired by modern spreadsheet applications
- **CSV Export**: Generate and share CSV files via email, SMS, or save to files
- **DriverKit Integration**: Native USB serial communication using iPadOS DriverKit
- **ESP3 Protocol**: Full support for EnOcean Serial Protocol 3 (ESP3)

## Requirements

### Hardware
- **iPad with M1 chip or later** (DriverKit requirement)
  - iPad Pro (M1/M2)
  - iPad Air (M1)
- **EnOcean USB dongle** (TCM310 or compatible FTDI-based device)
- **USB-C cable** or adapter to connect dongle to iPad

### Software
- iPadOS 16.0 or later
- Xcode 14.0 or later (for development)
- Apple Developer account (for DriverKit entitlements)

## Project Structure

```
EnoceanMapper/
├── App/                           # iPad application
│   ├── EnoceanMapperApp.swift    # App entry point
│   ├── ContentView.swift         # Main UI with spreadsheet layout
│   ├── MapperViewModel.swift     # View model for state management
│   ├── SerialPortManager.swift   # Serial communication layer
│   ├── Models.swift              # Data models and CSV export
│   ├── Info.plist               # App configuration
│   └── App.entitlements         # App entitlements
├── Driver/                       # DriverKit extension
│   ├── EnoceanDriver.swift      # USB serial driver implementation
│   ├── Info.plist               # Driver configuration
│   └── Driver.entitlements      # Driver entitlements
└── Shared/                       # Shared code
    └── ESP3Protocol.swift        # EnOcean ESP3 protocol implementation
```

## Setup Instructions

### 1. Create Xcode Project

Since this is command-line generated code, you'll need to create the Xcode project manually:

1. Open Xcode and create a new **App** project
2. Set the following:
   - **Product Name**: EnoceanMapper
   - **Bundle Identifier**: com.yourcompany.enoceanmapper (use your own)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Platform**: iPad

### 2. Add DriverKit Extension

1. In Xcode: **File → New → Target**
2. Choose **DriverKit → System Extension**
3. Set:
   - **Product Name**: EnoceanDriver
   - **Bundle Identifier**: com.yourcompany.enoceanmapper.driver

### 3. Import Source Files

1. Delete the default Swift files created by Xcode
2. Drag and drop files from this repository:
   - `App/*` → App target
   - `Driver/*` → Driver target
   - `Shared/*` → Both targets (check both in File Inspector)

### 4. Configure Bundle Identifiers

Update the bundle identifiers in both targets to match your Apple Developer account:

**App Target:**
- Bundle ID: `com.yourcompany.enoceanmapper`

**Driver Target:**
- Bundle ID: `com.yourcompany.enoceanmapper.driver` (must be prefixed with app bundle ID)

### 5. Configure Entitlements

#### App Entitlements (`App.entitlements`)

Replace the driver bundle ID if you changed it:

```xml
<key>com.apple.developer.driverkit.communicates-with-drivers</key>
<array>
    <string>com.yourcompany.enoceanmapper.driver</string>
</array>
```

#### Driver Entitlements (`Driver.entitlements`)

The FTDI vendor ID (0x0403) is already configured. For production release, you'll need to request this entitlement from Apple.

### 6. Request Production Entitlements (For App Store)

For development, Xcode will auto-sign with development entitlements. For production:

1. Visit: https://developer.apple.com/contact/request/system-extension/
2. Fill out the form requesting DriverKit entitlements for:
   - **Vendor ID**: 0x0403 (FTDI)
   - **Use Case**: EnOcean wireless device mapping with TCM310 USB dongle
3. Wait for Apple approval (typically 1-2 weeks)

### 7. Build and Run

1. Connect your M1 iPad to your Mac
2. Select your iPad as the deployment target
3. Build and run (⌘R)

### 8. Enable Driver on iPad

**First-time setup on iPad:**

1. Install the app on your iPad
2. Go to **Settings → General → DriverKit**
3. Find **EnoceanDriver** and toggle it ON
4. Connect the EnOcean USB dongle

## Usage

### Scanning for Devices

1. **Connect USB Dongle**: Plug the EnOcean TCM310 dongle into your iPad via USB-C
2. **Start Listening**: Tap the green "Start Listening" button
3. **Trigger Devices**: Press buttons, trigger sensors, etc. to make devices transmit
4. **View Results**: Switch between "Devices" and "Packets" tabs to see data

### Understanding the UI

#### Devices Tab
Shows discovered devices with:
- **Device ID**: Unique 8-digit hex identifier (e.g., `01A2B3C4`)
- **Type**: Device type based on R-ORG (Switch, Sensor, Contact, etc.)
- **Packets**: Total number of packets received from this device
- **RSSI**: Signal strength (best and average in dBm)
- **First/Last Seen**: Timestamps of first and most recent packet

#### Packets Tab
Shows all captured packets with:
- **Time**: When the packet was received
- **Device ID**: Sender device identifier
- **Type**: Packet type (color-coded)
- **RSSI**: Signal strength (-60 dBm = excellent, -75 dBm = good, <-75 dBm = weak)
- **Payload**: Raw data bytes in hexadecimal
- **Status**: Status byte in binary format

### Exporting Data

1. Tap the **Export** button in the control panel
2. Choose:
   - **Export Devices**: CSV file with device summary
   - **Export Packets**: CSV file with all packets
   - **Export All Data**: Combined CSV with both
3. Share via:
   - **Save to Files**: Save to iCloud Drive or local storage
   - **Email**: Send as attachment
   - **Messages**: Share via SMS/iMessage
   - **AirDrop**: Send to nearby devices

### CSV Format

#### Devices CSV
```csv
Device ID,Device Type,RORG,First Seen,Last Seen,Packet Count,Best RSSI,Worst RSSI,Average RSSI
01A2B3C4,"Switch (RPS)",0xF6,2025-01-15T10:30:00Z,2025-01-15T10:35:00Z,12,-65,-72,-68
```

#### Packets CSV
```csv
Timestamp,Device ID,Device Type,RORG,RSSI,Payload (Hex),Status (Binary),SubTel#
2025-01-15T10:30:00Z,01A2B3C4,"Switch (RPS)",0xF6,-65,"F6 10",00001000,0
```

## Troubleshooting

### No Devices Found

1. **Check USB Connection**: Ensure dongle is properly connected
2. **Enable Driver**: Go to Settings → General → DriverKit and enable EnoceanDriver
3. **Check Permissions**: App should request serial device access
4. **Trigger Devices**: EnOcean devices only transmit when activated (button press, motion, etc.)

### Driver Not Appearing in Settings

1. **Check iPad Model**: Only M1/M2 iPads support DriverKit
2. **Rebuild Project**: Clean build folder and rebuild
3. **Check Bundle IDs**: Ensure driver bundle ID is prefixed with app bundle ID
4. **Check Entitlements**: Verify entitlements are properly configured

### Parse Errors or Corrupt Data

1. **Check Baud Rate**: TCM310 default is 57600 baud (configured automatically)
2. **Cable Quality**: Use high-quality USB cables
3. **EMI Interference**: Move away from sources of electromagnetic interference

### Low RSSI (Weak Signal)

- **Move Closer**: EnOcean typical range is 30-300m depending on obstacles
- **Remove Obstacles**: Metal and concrete significantly reduce signal
- **Check Antenna**: Some dongles have external antennas

## EnOcean Protocol Reference

### Supported R-ORG Types

| R-ORG | Value | Description | Common Devices |
|-------|-------|-------------|----------------|
| RPS | 0xF6 | Repeated Switch | Push buttons, wall switches |
| 1BS | 0xD5 | 1 Byte Sensor | Door/window contacts |
| 4BS | 0xA5 | 4 Byte Sensor | Temperature, humidity, motion sensors |
| VLD | 0xD2 | Variable Length | Complex devices |
| UTE | 0xD4 | Universal Teach-In | Learning mode devices |

### ESP3 Packet Structure

```
+------+--------+------+------+------+-----------+
| Sync | Header | CRC  | Data | Opt  | Data CRC  |
| 0x55 | 4 bytes| 1    | N    | M    | 1         |
+------+--------+------+------+------+-----------+
```

- **Sync Byte**: Always 0x55
- **Header**: Data length (2) + Optional length (1) + Packet type (1)
- **CRC8**: Separate checksums for header and data

## Technical Details

### Serial Configuration
- **Baud Rate**: 57600 (TCM310 default)
- **Data Bits**: 8
- **Parity**: None
- **Stop Bits**: 1
- **Flow Control**: Software (XON/XOFF)

### Memory Management
- **Packet Buffer**: Automatic overflow protection
- **Max Packets**: Limited only by device memory
- **Recommended**: Clear data after exporting for long sessions

### Thread Safety
- Serial reading on background thread
- UI updates on main thread via Combine
- Thread-safe data access with @Published properties

## Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/yourusername/EnoceanMapper.git

# Open in Xcode
open EnoceanMapper.xcodeproj
```

### Testing Without Hardware

For UI development without physical hardware:
1. Comment out serial port connection in `SerialPortManager.swift`
2. Use mock data generator (see development branch)

### Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## References

- [EnOcean Serial Protocol 3 (ESP3) Specification](https://www.enocean.com/wp-content/uploads/Knowledge-Base/EnOceanSerialProtocol3-1.pdf)
- [TCM310 Data Sheet](https://www.enocean.com/en/products/enocean_modules/tcm-310/)
- [Apple DriverKit Documentation](https://developer.apple.com/documentation/driverkit)
- [WWDC22: Bring your driver to iPad](https://developer.apple.com/videos/play/wwdc2022/110373/)

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- Open an issue on GitHub
- Email: support@yourcompany.com

## Acknowledgments

- EnOcean GmbH for the ESP3 protocol specification
- Apple for DriverKit framework
- FTDI for USB-serial chipsets

---

**Made with ❤️ for the EnOcean community**
