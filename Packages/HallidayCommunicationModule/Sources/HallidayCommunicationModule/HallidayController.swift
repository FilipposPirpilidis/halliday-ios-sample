// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import Combine
import Core

public final class HallidayController {
    private let manager: HallidayBLEManaging
    private let audioQueue = DispatchQueue(label: "halliday.audio.decode.serial", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var opusParser = ThreadSafeOpusTransportParser()
    private var opusDecoder = OpusDecoderWrapper()
    private let pcmStreamSubject = PassthroughSubject<Data, Never>()

    public var discoveredDevicesPublisher: AnyPublisher<[HallidayDiscoveredDevice], Never> {
        manager.discoveredDevicesPublisher
    }

    public var connectionStatePublisher: AnyPublisher<HallidayConnectionState, Never> {
        manager.connectionStatePublisher
    }

    public var logsPublisher: AnyPublisher<String, Never> {
        manager.logsPublisher
    }

    public var audioStreamPublisher: AnyPublisher<Data, Never> {
        manager.audioStreamPublisher
    }

    public var pcmStreamPublisher: AnyPublisher<Data, Never> {
        pcmStreamSubject.eraseToAnyPublisher()
    }

    public init(manager: HallidayBLEManaging = BLEManager()) {
        self.manager = manager
        bindAudioDecode()
    }

    public func startDiscovery() {
        manager.startDiscovery()
    }

    public func connect(target: HallidayTarget) {
        manager.start(target: target)
    }

    public func disconnect() {
        manager.disconnect()
    }

    public func sendRequestTemp() {
        manager.sendRequestTemp()
    }

    public func endDisplayCaptions() {
        manager.endDisplayCaptions()
    }

    public func sendTextToHallidayDisplay(_ text: String) {
        manager.sendTextToHallidayDisplay(text)
    }

    public func writeDisplay(_ data: Data) {
        manager.writeToDisplay(data)
    }

    public func writeAudio(_ data: Data) {
        manager.writeToAudio(data)
    }

    private func bindAudioDecode() {
        manager.audioStreamPublisher
            .receive(on: audioQueue)
            .sink { [weak self] chunk in
                guard let self else { return }
                let packets = self.opusParser.push(chunk)
                guard !packets.isEmpty else { return }

                for packet in packets {
                    guard let pcm = self.opusDecoder?.decode(packet: packet, maxFrameSamples: 320) else { continue }
                    self.pcmStreamSubject.send(pcm.toLittleEndianData())
                }
            }
            .store(in: &cancellables)
    }
}
