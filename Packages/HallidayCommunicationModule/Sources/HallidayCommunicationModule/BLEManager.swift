// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import CoreBluetooth
import Combine
import Core

public final class BLEManager: NSObject, HallidayBLEManaging {
    private static let queue = DispatchQueue(label: "halliday.ble.queue", qos: .userInitiated)

    private let discoveredDevicesSubject = CurrentValueSubject<[HallidayDiscoveredDevice], Never>([])
    private let connectionStateSubject = CurrentValueSubject<HallidayConnectionState, Never>(.disconnected)
    private let logsSubject = PassthroughSubject<String, Never>()
    private let audioStreamSubject = PassthroughSubject<Data, Never>()

    private lazy var centralManager = CBCentralManager(delegate: self, queue: Self.queue)

    private var target: HallidayTarget?
    private var connectedPeripheral: CBPeripheral?

    private var writeB754Characteristic: CBCharacteristic?
    private var notifyB754Characteristic: CBCharacteristic?
    private var writeAudioCharacteristic: CBCharacteristic?
    private var notifyAudioCharacteristic: CBCharacteristic?
    private var vendorCounter: UInt16 = 0x0024
    private var aiMsgId: UInt16 = 0x0216
    private var initSequenceStarted = false

    public var discoveredDevicesPublisher: AnyPublisher<[HallidayDiscoveredDevice], Never> {
        discoveredDevicesSubject.eraseToAnyPublisher()
    }

    public var connectionStatePublisher: AnyPublisher<HallidayConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public var logsPublisher: AnyPublisher<String, Never> {
        logsSubject.eraseToAnyPublisher()
    }

    public var audioStreamPublisher: AnyPublisher<Data, Never> {
        audioStreamSubject.eraseToAnyPublisher()
    }

    public override init() {
        super.init()
    }

    public func startDiscovery() {
        target = nil
        Self.queue.async { [weak self] in
            self?.startDiscoveryInternal(resetList: true)
        }
    }

    public func start(target: HallidayTarget) {
        self.target = target
        Self.queue.async { [weak self] in
            guard let self else { return }
            self.discoveredDevicesSubject.send([])
            self.connectIfKnownElseScanTarget()
        }
    }

    public func disconnect() {
        Self.queue.async { [weak self] in
            guard let self, let connectedPeripheral else { return }
            self.centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }

    public func sendRequestTemp() {
        // Same payload sequence from the example project, sent via vendor frame.
        let p1 = Data([0xFD, 0x00, 0x02, 0x00, 0x06, 0x02, 0x01, 0x10, 0x00, 0x00, 0x32])
        let p2 = Data([0xFD, 0x00, 0x02, 0x00, 0x06, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00])
        sendVendorCommand(payload: p1, logLabel: "sendRequestTemp p1")
        sendVendorCommand(payload: p2, logLabel: "sendRequestTemp p2")
    }

    public func endDisplayCaptions() {
        let payload = Data([0xFD, 0x00, 0x02, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        sendVendorCommand(payload: payload, logLabel: "endDisplayCaptions")
    }

    public func sendTextToHallidayDisplay(_ text: String) {
        guard connectedPeripheral != nil else {
            log("❌ sendTextToHallidayDisplay: not connected")
            return
        }
        guard writeB754Characteristic != nil else {
            log("❌ sendTextToHallidayDisplay: B754 write characteristic not ready")
            return
        }

        func makeDualTextPayload(msgId: UInt16, utf8: Data) -> Data {
            let idLo = UInt8(msgId & 0xFF)
            let idHi = UInt8((msgId >> 8) & 0xFF)

            let clipped = utf8.prefix(255)
            let len = UInt8(clipped.count)

            var payload = Data([0x05, 0x00, 0x02, 0x00, idLo, idHi, 0x00, 0x00, 0x00, len])
            payload.append(clipped)
            payload.append(contentsOf: [0x00, 0x00, len])
            payload.append(clipped)
            return payload
        }

        let msgId = nextAIMessageId()
        let textData = text.data(using: .utf8) ?? Data()

        sendVendorCommand(
            payload: makeDualTextPayload(msgId: msgId, utf8: textData),
            logLabel: "sendTextToHallidayDisplay id=0x\(String(format: "%04X", msgId))"
        )
    }

    private func initSequence() {
        Self.queue.async { [weak self] in
            guard let self else { return }

            Task {
                // didConnect fires before characteristics are always ready.
                for _ in 0..<60 {
                    if self.writeB754Characteristic != nil { break }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x43, 0x00, 0x01, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x3C, 0x00, 0x02, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x41, 0x00, 0x01, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x0E, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x01, 0x00, 0x02, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0xFC, 0x00, 0x01, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x08, 0x00, 0x01, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0xFC, 0x00, 0x01, 0x00, 0x00]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x41, 0x00, 0x01, 0x01]), logLabel: "INIT PROCESS")
                try? await Task.sleep(nanoseconds: 10_000_000)

                self.sendVendorCommand(payload: Data([0x02, 0x00, 0x41, 0x00, 0x01, 0x01]), logLabel: "INIT PROCESS")
            }
        }
    }

    private func sendVendorCommand(payload: Data, logLabel: String) {
        guard let peripheral = connectedPeripheral else {
            log("❌ \(logLabel): not connected")
            return
        }

        guard let ch = writeB754Characteristic else {
            log("❌ \(logLabel): B754 write characteristic not ready")
            return
        }

        let len = UInt8(payload.count)
        let crc = crc16ARC(payload)
        let crcHigh = UInt8((crc >> 8) & 0xFF)
        let crcLow = UInt8(crc & 0xFF)

        let ctr = nextVendorCounter()
        let ctrLow = UInt8(ctr & 0xFF)
        let ctrHigh = UInt8((ctr >> 8) & 0xFF)

        var frame = Data([0x5F, 0x00, 0x00, len, crcHigh, crcLow, ctrLow, ctrHigh])
        frame.append(payload)

        peripheral.writeValue(frame, for: ch, type: .withoutResponse)
        log("➡️ \(logLabel): frameBytes=\(frame.count)")
    }

    private func nextVendorCounter() -> UInt16 {
        vendorCounter &+= 1
        return vendorCounter
    }

    private func nextAIMessageId() -> UInt16 {
        aiMsgId &+= 1
        return aiMsgId
    }

    private func crc16ARC(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0x0000
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if (crc & 0x0001) != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return crc
    }

    public func writeToDisplay(_ data: Data) {
        Self.queue.async { [weak self] in
            guard
                let self,
                let peripheral = self.connectedPeripheral,
                let characteristic = self.writeB754Characteristic
            else {
                self?.log("Display write skipped, characteristic not ready")
                return
            }
            let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(data, for: characteristic, type: type)
        }
    }

    public func writeToAudio(_ data: Data) {
        Self.queue.async { [weak self] in
            guard
                let self,
                let peripheral = self.connectedPeripheral,
                let characteristic = self.writeAudioCharacteristic
            else {
                self?.log("Audio write skipped, characteristic not ready")
                return
            }
            let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(data, for: characteristic, type: type)
        }
    }

    private func connectIfKnownElseScanTarget() {
        guard centralManager.state == .poweredOn else {
            connectionStateSubject.send(.error("Bluetooth is not powered on"))
            log("Bluetooth not ready: \(centralManager.state.rawValue)")
            return
        }

        guard let target else {
            connectionStateSubject.send(.error("Target device is missing"))
            return
        }

        let known = centralManager.retrievePeripherals(withIdentifiers: [target.deviceIdentifier])
        if let peripheral = known.first {
            upsertDevice(peripheral: peripheral, rssi: -50)
            log("Found known target \(peripheral.identifier.uuidString), connecting")
            connect(peripheral)
            return
        }

        startDiscoveryInternal(resetList: false)
    }

    private func startDiscoveryInternal(resetList: Bool) {
        guard centralManager.state == .poweredOn else {
            connectionStateSubject.send(.error("Bluetooth is not powered on"))
            log("Bluetooth not ready: \(centralManager.state.rawValue)")
            return
        }

        if resetList {
            discoveredDevicesSubject.send([])
        }

        let connected = centralManager.retrieveConnectedPeripherals(withServices: HallidayUUIDs.scanServices)
        for peripheral in connected {
            upsertDevice(peripheral: peripheral, rssi: -50)
        }

        connectionStateSubject.send(.scanning)
        log("Scanning Halliday services and listing connected peripherals")
        centralManager.scanForPeripherals(withServices: HallidayUUIDs.scanServices, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func connect(_ peripheral: CBPeripheral) {
        connectionStateSubject.send(.connecting)
        centralManager.stopScan()
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    private func upsertDevice(peripheral: CBPeripheral, rssi: Int) {
        let discovered = HallidayDiscoveredDevice(
            id: peripheral.identifier,
            name: peripheral.name ?? "Unknown",
            rssi: rssi,
            peripheral: peripheral
        )

        var current = discoveredDevicesSubject.value
        if let index = current.firstIndex(where: { $0.id == discovered.id }) {
            current[index] = discovered
        } else {
            current.append(discovered)
        }
        discoveredDevicesSubject.send(current)
    }

    private func resetCharacteristicHandles() {
        writeB754Characteristic = nil
        notifyB754Characteristic = nil
        writeAudioCharacteristic = nil
        notifyAudioCharacteristic = nil
        initSequenceStarted = false
    }

    private func log(_ message: String) {
        logsSubject.send(message)
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

extension BLEManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStateSubject.send(.disconnected)
            if let target {
                start(target: target)
            } else {
                startDiscoveryInternal(resetList: false)
            }
        case .poweredOff:
            connectionStateSubject.send(.error("Bluetooth is powered off"))
        case .unauthorized:
            connectionStateSubject.send(.error("Bluetooth unauthorized"))
        case .unsupported:
            connectionStateSubject.send(.error("Bluetooth unsupported"))
        case .resetting:
            connectionStateSubject.send(.error("Bluetooth resetting"))
        case .unknown:
            connectionStateSubject.send(.error("Bluetooth unknown"))
        @unknown default:
            connectionStateSubject.send(.error("Bluetooth unknown"))
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        upsertDevice(peripheral: peripheral, rssi: RSSI.intValue)

        guard let target else { return }
        guard peripheral.identifier == target.deviceIdentifier else { return }

        log("Target discovered \(peripheral.identifier.uuidString), connecting")
        connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        resetCharacteristicHandles()
        connectionStateSubject.send(.connected)
        log("Connected to \(peripheral.identifier.uuidString)")
        // Discover all services first so we can verify runtime service map.
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStateSubject.send(.error("Failed to connect: \(error?.localizedDescription ?? "Unknown")"))
        log("Connection failed for \(peripheral.identifier.uuidString)")

        if target == nil {
            startDiscoveryInternal(resetList: false)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        resetCharacteristicHandles()
        connectionStateSubject.send(.disconnected)
        log("Disconnected \(peripheral.identifier.uuidString)")
    }
}

extension BLEManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectionStateSubject.send(.error("Service discovery failed: \(error.localizedDescription)"))
            return
        }

        guard let services = peripheral.services else { return }
        let discoveredServiceUUIDs = services.map(\.uuid.uuidString).joined(separator: ", ")
        log("Discovered services: \(discoveredServiceUUIDs)")
        for service in services where HallidayUUIDs.scanServices.contains(service.uuid) {
            log("Discovering characteristics for service \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            connectionStateSubject.send(.error("Characteristic discovery failed: \(error.localizedDescription)"))
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            log("Found characteristic \(characteristic.uuid.uuidString) on \(service.uuid.uuidString) props=\(characteristic.properties.rawValue)")
            switch (service.uuid, characteristic.uuid) {
            case (HallidayUUIDs.writeB754Service, HallidayUUIDs.writeB754Char):
                writeB754Characteristic = characteristic
                log("B754 write characteristic ready")
            case (HallidayUUIDs.writeB754Service, HallidayUUIDs.notifyB754Char):
                notifyB754Characteristic = characteristic
                log("Requesting notify enable for B754 notify characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
                if !initSequenceStarted {
                    initSequenceStarted = true
                    log("Starting initSequence after B754 notify characteristic discovery")
                    initSequence()
                }
            case (HallidayUUIDs.audioService01A6BAAD, HallidayUUIDs.write01A6BWrite):
                writeAudioCharacteristic = characteristic
                log("Audio write characteristic ready")
            case (HallidayUUIDs.audioService01A6BAAD, HallidayUUIDs.audioNotify01A6BAAF):
                notifyAudioCharacteristic = characteristic
                log("Requesting notify enable for audio notify characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("❌ Notify state update failed for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        let state = characteristic.isNotifying ? "ENABLED" : "DISABLED"
        log("✅ Notify state \(state) for \(characteristic.uuid.uuidString)")
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("Notify read error \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        guard let value = characteristic.value else { return }

        if characteristic.uuid == HallidayUUIDs.notifyB754Char {
            log("B754 notify (\(value.count) bytes): \(hexString(value))")
        } else if characteristic.uuid == HallidayUUIDs.audioNotify01A6BAAF {
            log("Audio notify (\(value.count) bytes): \(hexString(value))")
            audioStreamSubject.send(value)
        }
    }
}
