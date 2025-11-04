# Building EnOcean Mapper

Detailed instructions for setting up the Xcode project and building the app.

## Quick Start

If you're familiar with Xcode and DriverKit:
1. Create new iPad App project in Xcode
2. Add DriverKit System Extension target
3. Import source files from this repository
4. Configure bundle IDs and entitlements
5. Build and deploy to M1 iPad

## Detailed Setup

### Step 1: Create App Project

1. Launch Xcode 14 or later
2. Choose **File → New → Project**
3. Select **iOS → App**
4. Configure:
   - **Product Name**: `EnoceanMapper`
   - **Team**: Select your development team
   - **Organization Identifier**: `com.yourcompany` (use your own)
   - **Bundle Identifier**: Will be `com.yourcompany.enoceanmapper`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Include Tests**: Optional
5. Click **Next** and choose a location to save

### Step 2: Configure App Target

1. Select project in Navigator
2. Select **EnoceanMapper** app target
3. **General tab**:
   - **Supported Destinations**: iPad only (uncheck iPhone)
   - **Minimum Deployments**: iPadOS 16.0
   - **Supported orientations**: All (Portrait, Landscape Left, Landscape Right)

4. **Signing & Capabilities tab**:
   - Enable **Automatically manage signing**
   - Select your **Team**
   - Click **+ Capability** and add:
     - **DriverKit** (this creates the communicates-with-drivers entitlement)

### Step 3: Add DriverKit Extension Target

1. **File → New → Target**
2. Select **DriverKit → System Extension**
3. Configure:
   - **Product Name**: `EnoceanDriver`
   - **Team**: Same as app
   - **Language**: Swift
   - **Bundle Identifier**: Should auto-fill as `com.yourcompany.enoceanmapper.driver`
     - **IMPORTANT**: Must use app bundle ID as prefix
4. Click **Finish**
5. When prompted to activate scheme, click **Activate**

### Step 4: Configure Driver Target

1. Select **EnoceanDriver** target
2. **General tab**:
   - **Supported Destinations**: iPad only
   - **Minimum Deployments**: iPadOS 16.0

3. **Signing & Capabilities tab**:
   - Enable **Automatically manage signing**
   - Entitlements should include:
     - `com.apple.developer.driverkit` = true
     - `com.apple.developer.driverkit.family.serial` = true
     - `com.apple.developer.driverkit.transport.usb` = ["0x0403"]

### Step 5: Import Source Files

1. Delete default Swift files:
   - Delete `ContentView.swift` in app target (we'll replace it)
   - Delete the default driver `.swift` file in driver target

2. Import App files:
   - Drag `App/` folder contents into Xcode
   - **Add to targets**: Check only **EnoceanMapper** app
   - Replace files if prompted

3. Import Driver files:
   - Drag `Driver/` folder contents into Xcode
   - **Add to targets**: Check only **EnoceanDriver** extension
   - Replace files if prompted

4. Import Shared files:
   - Drag `Shared/` folder contents into Xcode
   - **Add to targets**: Check **both** targets
   - This allows both app and driver to use the ESP3Protocol code

### Step 6: Configure Info.plist Files

#### App Info.plist

Xcode should auto-generate most settings. Verify these are present:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
</dict>
```

You can use the provided `App/Info.plist` file or let Xcode manage it automatically.

#### Driver Info.plist

**CRITICAL**: The driver Info.plist contains IOKit matching properties:

1. Open `Driver/Info.plist`
2. Verify the `IOKitPersonalities` section:
   - `idVendor`: 1027 (decimal for 0x0403 - FTDI)
   - `idProduct`: 24577 (decimal for 0x6001 - FT232)
3. Update `CFBundleIdentifier` under `IOKitPersonalities` to match your driver bundle ID

### Step 7: Configure Entitlements

#### App Entitlements

1. Select app target
2. **Signing & Capabilities → App Sandbox** (if present, disable for iPad)
3. Open `App.entitlements` file
4. Update the driver bundle ID if you changed it:

```xml
<key>com.apple.developer.driverkit.communicates-with-drivers</key>
<array>
    <string>com.yourcompany.enoceanmapper.driver</string>
</array>
```

#### Driver Entitlements

1. Select driver target
2. Open `Driver.entitlements`
3. Verify USB vendor ID:

```xml
<key>com.apple.developer.driverkit.transport.usb</key>
<array>
    <string>0x0403</string>
</array>
```

### Step 8: Build Settings

#### App Target Build Settings

Search for these settings and verify:

- **Product Bundle Identifier**: `com.yourcompany.enoceanmapper`
- **Code Signing Identity**: Apple Development
- **Development Team**: Your team

#### Driver Target Build Settings

- **Product Bundle Identifier**: `com.yourcompany.enoceanmapper.driver`
- **Code Signing Identity**: Apple Development
- **Development Team**: Your team (same as app)

### Step 9: Embed Driver in App

1. Select app target
2. **General tab → Frameworks, Libraries, and Embedded Content**
3. Click **+** button
4. Select **EnoceanDriver** (the system extension)
5. Set to **Embed & Sign**

If this option is not available, the driver will be embedded automatically.

### Step 10: Build and Run

1. Connect M1 iPad via USB-C
2. Unlock iPad and trust computer
3. Select scheme: **EnoceanMapper → Your iPad**
4. **Product → Build** (⌘B) to verify compilation
5. **Product → Run** (⌘R) to deploy to iPad

### Step 11: Enable Driver on iPad

**First-time installation:**

1. App will install on iPad
2. Open **Settings** app on iPad
3. Navigate to **General → DriverKit**
4. Find **EnoceanDriver** in the list
5. Toggle **ON**
6. Return to EnoceanMapper app

**Note**: You only need to enable the driver once. It will remain enabled until you uninstall the app.

## Verification Steps

### Verify Build Success

After building, check:

1. No compilation errors in Xcode
2. App appears in build products
3. Driver extension is embedded in app bundle

### Verify Installation

On iPad:

1. App icon appears on home screen
2. App launches without crashing
3. Driver appears in Settings → General → DriverKit

### Verify Driver Activation

1. Enable driver in Settings
2. Connect EnOcean USB dongle
3. Open EnoceanMapper app
4. Tap "Start Listening"
5. Should show "Listening for EnOcean devices..."

If it shows "No EnOcean device found", see Troubleshooting below.

## Troubleshooting

### Build Errors

#### "No such module 'DriverKit'"

- **Solution**: Ensure driver target has DriverKit entitlements
- Check target build settings for DriverKit framework

#### "Embedded binary is not signed with the same certificate"

- **Solution**: Both app and driver must use same development team
- Check **Signing & Capabilities** for both targets

#### "Bundle identifier mismatch"

- **Solution**: Driver bundle ID must be prefixed with app bundle ID
- Example: `com.company.app` and `com.company.app.driver`

### Linker Errors

#### "Undefined symbol: _OBJC_CLASS_$_IOUserUSBSerial"

- **Solution**: Add `USBSerialDriverKit.framework` to driver target
- **Build Phases → Link Binary With Libraries → + → USBSerialDriverKit**

#### "Duplicate symbol: ESP3Protocol"

- **Solution**: Ensure `ESP3Protocol.swift` is added to both targets
- Check **Target Membership** in File Inspector

### Runtime Errors

#### "Driver not appearing in Settings"

1. Check iPad is M1 or later
2. Verify driver bundle ID is correct
3. Rebuild and reinstall
4. Restart iPad

#### "Failed to open serial port"

1. Check USB cable connection
2. Verify dongle is FTDI-based (0x0403 vendor ID)
3. Check driver is enabled in Settings
4. Try different USB-C adapter/hub

#### "No devices detected"

1. Ensure EnOcean devices are being triggered (button press, etc.)
2. EnOcean devices only transmit when active
3. Check RSSI - may be out of range
4. Verify dongle LED is blinking (if equipped)

## Advanced Configuration

### Custom Baud Rates

To change the baud rate (default is 57600):

1. Open `Driver/EnoceanDriver.swift`
2. Modify `defaultBaudRate` constant
3. Rebuild and redeploy

### Custom Vendor/Product IDs

If using a different FTDI device:

1. Find USB vendor/product IDs using `system_profiler SPUSBDataType`
2. Update `Driver/Info.plist`:
   - `idVendor`: Decimal value of vendor ID
   - `idProduct`: Decimal value of product ID
3. Update `Driver.entitlements`:
   - Add vendor ID in hex format to USB array
4. Request entitlement from Apple for production

### Debug Logging

To enable verbose logging:

1. Open `Driver/EnoceanDriver.swift`
2. Change `os_log` type from `.info` to `.debug`
3. View logs in **Console.app** on Mac while iPad is connected

## Testing Without Hardware

For UI testing without physical dongle:

1. Comment out serial port connection in `SerialPortManager.swift`
2. Add mock data injection:

```swift
func startListening() {
    // Mock mode for testing
    state = .listening
    injectMockData()
}

private func injectMockData() {
    // Create fake ESP3 packets
    let mockPacket = ESP3Packet(...)
    processPacket(mockPacket)
}
```

## Production Deployment

### Request Entitlements

For App Store distribution:

1. Visit: https://developer.apple.com/contact/request/system-extension/
2. Provide:
   - Team ID
   - Bundle IDs (app + driver)
   - USB Vendor ID (0x0403 for FTDI)
   - Justification (EnOcean device mapping)
3. Wait for approval (1-2 weeks)

### Archive for App Store

1. Select **Any iOS Device (arm64)** as destination
2. **Product → Archive**
3. **Window → Organizer**
4. Select archive and click **Distribute App**
5. Follow App Store submission process

### TestFlight Distribution

1. Archive as above
2. Choose **TestFlight** distribution
3. Upload to App Store Connect
4. Add testers via email
5. Testers must have M1 iPads

## Build Configurations

### Debug Configuration

- Enables console logging
- No optimizations
- Larger binary size
- Faster build time

### Release Configuration

- Minimal logging
- Full optimizations
- Smaller binary size
- Slower build time

Switch in Xcode: **Product → Scheme → Edit Scheme → Build Configuration**

## Additional Resources

- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [DriverKit Programming Guide](https://developer.apple.com/documentation/driverkit/creating_a_driver_using_the_driverkit_sdk)
- [App Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## Getting Help

If you encounter issues:

1. Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Restart Xcode
4. Restart iPad
5. Check Console.app on Mac for crash logs
6. Open an issue on GitHub with:
   - Xcode version
   - iPadOS version
   - Build logs
   - Console logs

---

**Good luck building! 🚀**
