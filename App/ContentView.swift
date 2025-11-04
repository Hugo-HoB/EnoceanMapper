//
//  ContentView.swift
//  EnoceanMapper
//
//  Main UI with spreadsheet-style layout
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var viewModel = MapperViewModel()
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    @State private var shareContent: String = ""
    @State private var shareFileName: String = "export.csv"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Control Panel
                controlPanel

                Divider()

                // Status Bar
                statusBar

                Divider()

                // Tab Selection
                Picker("View", selection: $selectedTab) {
                    Text("Devices (\(viewModel.devices.count))").tag(0)
                    Text("Packets (\(viewModel.packets.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if selectedTab == 0 {
                    devicesTable
                } else {
                    packetsTable
                }
            }
            .navigationTitle("EnOcean Mapper")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(content: shareContent, fileName: shareFileName)
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        HStack(spacing: 12) {
            // Start/Stop Button
            Button(action: {
                if viewModel.state.isListening {
                    viewModel.stopListening()
                } else {
                    viewModel.startListening()
                }
            }) {
                Label(
                    viewModel.state.isListening ? "Stop Listening" : "Start Listening",
                    systemImage: viewModel.state.isListening ? "stop.circle.fill" : "play.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.state.isListening ? .red : .green)
            .disabled(viewModel.state.isListening ? false : false)

            // Clear Button
            Button(action: {
                viewModel.clearData()
            }) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.state.isListening || (viewModel.devices.isEmpty && viewModel.packets.isEmpty))

            // Export Menu
            Menu {
                Button(action: {
                    exportDevices()
                }) {
                    Label("Export Devices", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.devices.isEmpty)

                Button(action: {
                    exportPackets()
                }) {
                    Label("Export Packets", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.packets.isEmpty)

                Button(action: {
                    exportAll()
                }) {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.devices.isEmpty && viewModel.packets.isEmpty)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.devices.isEmpty && viewModel.packets.isEmpty)
        }
        .padding()
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray6))
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .idle:
            return .gray
        case .listening:
            return .green
        case .error:
            return .red
        }
    }

    // MARK: - Devices Table

    private var devicesTable: some View {
        Group {
            if viewModel.devices.isEmpty {
                emptyStateView(
                    icon: "antenna.radiowaves.left.and.right",
                    message: "No devices detected yet",
                    subtitle: "Start listening to discover EnOcean devices"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header
                        devicesTableHeader

                        Divider()

                        // Rows
                        ForEach(viewModel.devices) { device in
                            deviceRow(device)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var devicesTableHeader: some View {
        HStack(spacing: 8) {
            Text("Device ID")
                .frame(width: 120, alignment: .leading)
            Text("Type")
                .frame(width: 100, alignment: .leading)
            Text("Packets")
                .frame(width: 70, alignment: .trailing)
            Text("RSSI")
                .frame(width: 80, alignment: .trailing)
            Text("First Seen")
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("Last Seen")
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray5))
    }

    private func deviceRow(_ device: EnOceanDevice) -> some View {
        HStack(spacing: 8) {
            Text(device.id)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120, alignment: .leading)

            Text(device.deviceType)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(deviceTypeColor(device.rorg).opacity(0.2))
                .foregroundColor(deviceTypeColor(device.rorg))
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)

            Text("\(device.packetCount)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 70, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(device.bestRSSI) dBm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(rssiColor(device.bestRSSI))
                Text("avg: \(device.averageRSSI)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .trailing)

            Text(device.firstSeen, style: .time)
                .font(.caption)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(device.lastSeen, style: .time)
                .font(.caption)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Packets Table

    private var packetsTable: some View {
        Group {
            if viewModel.packets.isEmpty {
                emptyStateView(
                    icon: "tray",
                    message: "No packets received yet",
                    subtitle: "Start listening to capture EnOcean packets"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header
                        packetsTableHeader

                        Divider()

                        // Rows (show most recent first)
                        ForEach(viewModel.packets.reversed()) { packet in
                            packetRow(packet)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var packetsTableHeader: some View {
        HStack(spacing: 8) {
            Text("Time")
                .frame(width: 80, alignment: .leading)
            Text("Device ID")
                .frame(width: 120, alignment: .leading)
            Text("Type")
                .frame(width: 80, alignment: .leading)
            Text("RSSI")
                .frame(width: 60, alignment: .trailing)
            Text("Payload")
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("Status")
                .frame(width: 80, alignment: .leading)
        }
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray5))
    }

    private func packetRow(_ packet: EnOceanPacket) -> some View {
        HStack(spacing: 8) {
            Text(packet.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .leading)

            Text(packet.deviceId)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 120, alignment: .leading)

            Text(packet.deviceType)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(deviceTypeColor(packet.rorg).opacity(0.2))
                .foregroundColor(deviceTypeColor(packet.rorg))
                .cornerRadius(3)
                .frame(width: 80, alignment: .leading)

            Text("\(packet.rssi)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(rssiColor(packet.rssi))
                .frame(width: 60, alignment: .trailing)

            Text(packet.payloadHex)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(packet.statusBinary)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, message: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(message)
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private func deviceTypeColor(_ rorg: UInt8) -> Color {
        switch rorg {
        case 0xF6: return .blue    // Switch
        case 0xD5: return .purple  // Contact
        case 0xA5: return .orange  // Sensor
        case 0xD2: return .green   // VLD
        default: return .gray
        }
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -60 {
            return .green
        } else if rssi >= -75 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Export Functions

    private func exportDevices() {
        shareContent = viewModel.exportDevicesCSV()
        shareFileName = "enocean_devices_\(timestamp()).csv"
        showingShareSheet = true
    }

    private func exportPackets() {
        shareContent = viewModel.exportPacketsCSV()
        shareFileName = "enocean_packets_\(timestamp()).csv"
        showingShareSheet = true
    }

    private func exportAll() {
        shareContent = viewModel.exportCombinedCSV()
        shareFileName = "enocean_export_\(timestamp()).csv"
        showingShareSheet = true
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let content: String
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing file: \(error)")
        }

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
