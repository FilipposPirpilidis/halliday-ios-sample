// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import Combine
import CoreBluetooth

public protocol HallidayBLEManaging: AnyObject {
    var discoveredDevicesPublisher: AnyPublisher<[HallidayDiscoveredDevice], Never> { get }
    var connectionStatePublisher: AnyPublisher<HallidayConnectionState, Never> { get }
    var logsPublisher: AnyPublisher<String, Never> { get }
    var audioStreamPublisher: AnyPublisher<Data, Never> { get }

    func startDiscovery()
    func start(target: HallidayTarget)
    func disconnect()
    func sendRequestTemp()
    func endDisplayCaptions()
    func sendTextToHallidayDisplay(_ text: String)
    func writeToDisplay(_ data: Data)
    func writeToAudio(_ data: Data)
}
