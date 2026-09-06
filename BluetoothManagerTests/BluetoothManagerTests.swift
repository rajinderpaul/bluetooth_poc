//
//  BluetoothManagerTests.swift
//  BluetoothManagerTests
//
//  Created by Rajinder Paul on 05/09/26.
//

import Testing
import Foundation
@testable import BluetoothManager

struct BluetoothManagerTests {
	
	@Test("decodes a valid little-endian frame: seq + float")
	func decodesValidFrame() {
		// seq = 9 (0x00000009 LE → 09 00 00 00)
		// value = 1500.0  →  IEEE-754 bits 0x44BB8000  →  LE bytes 00 80 BB 44
		let data = Data([0x09, 0x00, 0x00, 0x00,
						 0x00, 0x80, 0xBB, 0x44])
		
		let frame = TelemetryFrame(data)
		
		#expect(frame != nil)
		#expect(frame?.seq == 9)
		#expect(frame?.value == 1500.0)
	}
	
	@Test("rejects a short packet: CHECK IF THIS FOUND")
	func rejectsShortPacket() {
		let data = Data([0x01, 0x02, 0x03])   // only 3 bytes
		#expect(TelemetryFrame(data) == nil)
	}
	
	@Test("rejects empty data")
	func rejectsEmpty() {
		#expect(TelemetryFrame(Data()) == nil)
	}
	
	@Test("decodes max UInt32 sequence (wraparound boundary)")
	func decodesMaxSeq() {
		// seq = 0xFFFFFFFF → LE FF FF FF FF ; value = 0.0 → 00 00 00 00
		let data = Data([0xFF, 0xFF, 0xFF, 0xFF,
						 0x00, 0x00, 0x00, 0x00])
		let frame = TelemetryFrame(data)
		#expect(frame?.seq == 4_294_967_295)
		#expect(frame?.value == 0.0)
	}
	
	
	@Test("decodes representative RPM values", arguments: [
		(seq: UInt32(1),   rpm: Float(1460.0)),
		(seq: UInt32(100), rpm: Float(1500.0)),
		(seq: UInt32(999), rpm: Float(1540.0)),
	])
	func decodesVariousValues(seq: UInt32, rpm: Float) {
		var data = Data()
		withUnsafeBytes(of: seq.littleEndian) { data.append(contentsOf: $0) }
		withUnsafeBytes(of: rpm.bitPattern.littleEndian) { data.append(contentsOf: $0) }

		let frame = TelemetryFrame(data)
		#expect(frame?.seq == seq)
		#expect(frame?.value == rpm)
	}
	
}
