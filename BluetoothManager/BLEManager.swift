//
//  BLEmanager.swift
//  BluetoothManager
//
//  Created by Rajinder Paul on 05/09/26.
//

import Foundation
import CoreBluetooth

// Arbitrary custom 128-bit UUIDs. In a real product these come from the embedded team's GATT spec — central and peripheral MUST agree on them.
enum GATT {
	static let service   = CBUUID(string: "0FD10001-1234-5678-9ABC-DEF012345678")
	static let telemetry = CBUUID(string: "0FD10002-1234-5678-9ABC-DEF012345678") // notify
	static let command   = CBUUID(string: "0FD10003-1234-5678-9ABC-DEF012345678") // write
	
	static let deviceInfo   = CBUUID(string: "180A")
	static let manufacturer = CBUUID(string: "2A29")
	static let modelNumber  = CBUUID(string: "2A24")
	static let firmwareRev  = CBUUID(string: "2A26")
	static let serialNumber = CBUUID(string: "2A25")


}

@Observable
final class BLECentralManager: NSObject {
	
	struct Discovered: Identifiable {
		let id: UUID; let name: String; let rssi: Int; let peripheral: CBPeripheral
	}
	
	var status = "Idle"
	var discovered: [Discovered] = []
	var isConnected = false
	var latestSeq: UInt32 = 0
	var latestValue: Float = 0
	var logLines: [String] = []
	
	var deviceManufacturer = ""
	var deviceModel = ""
	var deviceFirmware = ""
	var deviceSerial = ""
	
	
	private var central: CBCentralManager!
	private var target: CBPeripheral?
	private var commandChar: CBCharacteristic?
	private var shouldReconnect = false
	
	override init() {
		super.init()
		// queue: nil → callbacks arrive on the main queue, so touching @Published
		// state directly is safe. In production you'd use a dedicated queue.
		central = CBCentralManager(delegate: self, queue: nil)
	}
	
	func startScan() {
		guard central.state == .poweredOn else { status = "Bluetooth not ready"; return }
		discovered.removeAll();
		status = "Scanning…"
		// [GATT.service] surfaces only OUR peripheral. Pass nil to see every advertiser.
		central.scanForPeripherals(withServices: [GATT.service], options: nil)
	}
	
	func connect(_ d: Discovered) {
		shouldReconnect = false
		target = d.peripheral;
		d.peripheral.delegate = self
		central.stopScan();
		status = "Connecting…"
		central.connect(d.peripheral, options: nil)
	}
	
	func disconnect() {
			shouldReconnect = false
			if let t = target { central.cancelPeripheralConnection(t) }
		}
	
	func send(_ byte: UInt8) {
		guard let t = target, let c = commandChar else { return }
		t.writeValue(Data([byte]), for: c, type: .withResponse)
		logLines.append("→ command 0x\(String(byte, radix: 16))")
	}
}


// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
	func centralManagerDidUpdateState(_ c: CBCentralManager) {
		switch c.state {
		case .poweredOn:    status = "Ready — tap Scan"
		case .poweredOff:   status = "Bluetooth is off"
		case .unauthorized: status = "Bluetooth not authorized"
		default:            status = "State \(c.state.rawValue)"
		}
	}
	func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
						advertisementData ad: [String: Any], rssi: NSNumber) {
		let name = (ad[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? "Unknown"
		if !discovered.contains(where: { $0.id == p.identifier }) {
			discovered.append(.init(id: p.identifier, name: name, rssi: rssi.intValue, peripheral: p))
		}
	}
	func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
		isConnected = true;
		status = "Connected — discovering services";
		logLines.append("✓ connected")
		p.discoverServices([GATT.service, GATT.deviceInfo])
	}
	func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
		isConnected = false
		logLines.append("✗ disconnected\(error.map { " – \($0.localizedDescription)" } ?? "")")
		if shouldReconnect {                       // ← reconnection: the real-world money feature
			status = "Reconnecting…"; c.connect(p, options: nil)
		} else { status = "Disconnected" }
	}
	func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
		logLines.append("failed to connect"); if shouldReconnect { c.connect(p, options: nil) }
	}
}

// MARK: - CBPeripheralDelegate

extension BLECentralManager: CBPeripheralDelegate {
	func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
		for s in p.services ?? []  {
			if s.uuid == GATT.service  {
				p.discoverCharacteristics([GATT.telemetry, GATT.command], for: s)

			} else if s.uuid == GATT.deviceInfo {
				p.discoverCharacteristics(
					[GATT.manufacturer, GATT.modelNumber, GATT.firmwareRev, GATT.serialNumber], for: s)
			}
		}
	}
	func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
		for ch in s.characteristics ?? [] {
			switch ch.uuid {
			case GATT.telemetry:
				p.setNotifyValue(true, for: ch); logLines.append("subscribed")
			case GATT.command:
				commandChar = ch
			case GATT.manufacturer, GATT.modelNumber, GATT.firmwareRev, GATT.serialNumber:
				p.readValue(for: ch)          // ← trigger a read; result lands in didUpdateValueFor
			default:
				break
			}
			
		}
		status = "Streaming telemetry"
	}
	func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
		guard let d = ch.value else { return }
		
		switch ch.uuid {
			case GATT.telemetry:
			if let frame = TelemetryFrame(d) {
				latestSeq = frame.seq
				latestValue = frame.value
			}
			
			case GATT.manufacturer:
			deviceManufacturer = String(decoding: d, as: UTF8.self)
			case GATT.modelNumber:
			deviceModel        = String(decoding: d, as: UTF8.self)
			case GATT.firmwareRev:
			deviceFirmware     = String(decoding: d, as: UTF8.self)
			case GATT.serialNumber: deviceSerial       = String(decoding: d, as: UTF8.self)
			logLines.append("device: \(deviceManufacturer) \(deviceModel) fw \(deviceFirmware)")

			default: break
			}
		
		
	}
	
	func peripheral(_ p: CBPeripheral, didWriteValueFor ch: CBCharacteristic, error: Error?) {
		logLines.append("write ack\(error != nil ? " (error)" : "")")
	}
}
