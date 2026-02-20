// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import CoreBluetooth

public struct HallidayDiscoveredDevice: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let peripheral: CBPeripheral

    public init(id: UUID, name: String, rssi: Int, peripheral: CBPeripheral) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.peripheral = peripheral
    }

    public static func == (lhs: HallidayDiscoveredDevice, rhs: HallidayDiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}
