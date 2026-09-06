//
//  Untitled.swift
//  BluetoothManager
//
//  Created by Rajinder Paul on 06/09/26.
//

import Foundation

/// A decoded telemetry packet from the gateway.
/// Pure value type — no Core Bluetooth dependency, so it's unit-testable in isolation.
struct TelemetryFrame: Equatable {
	let seq: UInt32
	let value: Float

	/// Wire format: 8 bytes, little-endian — [UInt32 seq][Float32 value bits].
	/// Returns nil if the data isn't a valid frame (wrong length).
	init?(_ data: Data) {
		let b = [UInt8](data)
		guard b.count >= 8 else { return nil }

		let seq = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
		let rawBits = UInt32(b[4]) | UInt32(b[5]) << 8 | UInt32(b[6]) << 16 | UInt32(b[7]) << 24

		self.seq = seq
		self.value = Float(bitPattern: rawBits)
	}
}
