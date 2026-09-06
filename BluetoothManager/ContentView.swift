//
//  ContentView.swift
//  BluetoothManager
//
//  Created by Rajinder Paul on 05/09/26.
//

import SwiftUI

struct ContentView: View {
	@State private var ble = BLECentralManager()
	var body: some View {
		NavigationStack {
			List {
				Section("Status") {
					Text(ble.status)
					
					if ble.isConnected {
						LabeledContent("Seq", value: "\(ble.latestSeq)")
						LabeledContent("Value", value: String(format: "%.1f RPM", ble.latestValue))
						HStack {
							Button("Start") { ble.send(0x01) }
							Button("Stop")  { ble.send(0x00) }
							Button("Disconnect", role: .destructive) { ble.disconnect() }
						}.buttonStyle(.bordered)
					}
				}
				
				Section("Discovered") {
					ForEach(ble.discovered) { d in
						Button { ble.connect(d) } label: {
							HStack { Text(d.name); Spacer(); Text("\(d.rssi) dBm").foregroundStyle(.secondary) }
						}
					}
				}
				Section("Log") {
					ForEach(ble.logLines, id: \.self) {
						Text($0).font(.caption.monospaced())
					}
				}
				
				if !ble.deviceModel.isEmpty {
					Section("Device Info") {
						LabeledContent("Manufacturer", value: ble.deviceManufacturer)
						LabeledContent("Model", value: ble.deviceModel)
						LabeledContent("Firmware", value: ble.deviceFirmware)
						LabeledContent("Serial", value: ble.deviceSerial)
					}
				}
			}
			
			.navigationTitle("BLE Central")
			.toolbar { Button("Scan") { ble.startScan() } }
		}
		.padding()
	}
}

#Preview {
	ContentView()
}
