// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import Combine
import Core
import HallidayCommunicationModule

final class HomeViewModel {
    private enum Keys {
        static let targetDeviceUUID = "halliday.target.device.uuid"
    }

    private let defaults: UserDefaults
    private let controller = HallidayCommunicationModuleOrganizer.shared.hallidayController
    private let linkedTargetSubject = CurrentValueSubject<String, Never>("No linked target")
    private let transcriptSubject = CurrentValueSubject<String, Never>("")
    private let transcriptionService = PCMTranscriptionService()
    private var cancellables = Set<AnyCancellable>()
    private var lastFinalTranscriptSentToDisplay: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshLinkedTargetText()
        bindAudioToSpeech()
    }

    struct Input {
        let viewDidLoadIn: AnyPublisher<Void, Never>
        let connectTapIn: AnyPublisher<Void, Never>
        let disconnectTapIn: AnyPublisher<Void, Never>
        let openCaptionsTapIn: AnyPublisher<Void, Never>
        let endCaptionsTapIn: AnyPublisher<Void, Never>
        let unlinkTapIn: AnyPublisher<Void, Never>
        let deviceSelectedIn: AnyPublisher<HallidayDiscoveredDevice, Never>
    }

    struct Output {
        let connectionStateOut: AnyPublisher<HallidayConnectionState, Never>
        let discoveredDevicesOut: AnyPublisher<[HallidayDiscoveredDevice], Never>
        let logsOut: AnyPublisher<String, Never>
        let linkedTargetOut: AnyPublisher<String, Never>
        let transcriptOut: AnyPublisher<String, Never>
        let connectTapOut: AnyPublisher<Void, Never>
        let disconnectTapOut: AnyPublisher<Void, Never>
        let openCaptionsTapOut: AnyPublisher<Void, Never>
        let endCaptionsTapOut: AnyPublisher<Void, Never>
        let unlinkTapOut: AnyPublisher<Void, Never>
        let deviceSelectedOut: AnyPublisher<HallidayDiscoveredDevice, Never>
    }

    func convert(input: Input) -> Output {
        let connectTapHandler = input.connectTapIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.connectUsingSavedTargetOrStartDiscovery()
            })
            .eraseToAnyPublisher()

        let disconnectTapHandler = input.disconnectTapIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.controller.disconnect()
            })
            .eraseToAnyPublisher()

        let openCaptionsTapHandler = input.openCaptionsTapIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.controller.sendRequestTemp()
            })
            .eraseToAnyPublisher()

        let endCaptionsTapHandler = input.endCaptionsTapIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.controller.endDisplayCaptions()
            })
            .eraseToAnyPublisher()

        let unlinkTapHandler = input.unlinkTapIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.defaults.removeObject(forKey: Keys.targetDeviceUUID)
                self?.refreshLinkedTargetText()
                self?.controller.disconnect()
                self?.controller.startDiscovery()
            })
            .eraseToAnyPublisher()

        let deviceSelectedHandler = input.deviceSelectedIn
            .handleEvents(receiveOutput: { [weak self] device in
                guard let self else { return }
                self.defaults.set(device.id.uuidString, forKey: Keys.targetDeviceUUID)
                self.refreshLinkedTargetText()
                self.controller.connect(target: HallidayTarget(deviceIdentifier: device.id))
            })
            .eraseToAnyPublisher()

        let viewDidLoadHandler = input.viewDidLoadIn
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.transcriptionService.start()
                self?.connectUsingSavedTargetOrStartDiscovery()
            })
            .eraseToAnyPublisher()

        return Output(
            connectionStateOut: controller.connectionStatePublisher,
            discoveredDevicesOut: controller.discoveredDevicesPublisher,
            logsOut: controller.logsPublisher,
            linkedTargetOut: linkedTargetSubject.eraseToAnyPublisher(),
            transcriptOut: transcriptSubject.eraseToAnyPublisher(),
            connectTapOut: connectTapHandler.merge(with: viewDidLoadHandler).eraseToAnyPublisher(),
            disconnectTapOut: disconnectTapHandler,
            openCaptionsTapOut: openCaptionsTapHandler,
            endCaptionsTapOut: endCaptionsTapHandler,
            unlinkTapOut: unlinkTapHandler,
            deviceSelectedOut: deviceSelectedHandler
        )
    }

    private func connectUsingSavedTargetOrStartDiscovery() {
        if let target = savedTarget() {
            controller.connect(target: target)
        } else {
            controller.startDiscovery()
        }
    }

    private func savedTarget() -> HallidayTarget? {
        guard let uuidString = defaults.string(forKey: Keys.targetDeviceUUID) else { return nil }
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        return HallidayTarget(deviceIdentifier: uuid)
    }

    private func refreshLinkedTargetText() {
        if let uuid = defaults.string(forKey: Keys.targetDeviceUUID), !uuid.isEmpty {
            linkedTargetSubject.send("Linked target: \(uuid)")
        } else {
            linkedTargetSubject.send("No linked target")
        }
    }

    private func bindAudioToSpeech() {
        controller.pcmStreamPublisher
            .sink { [weak self] pcmData in
                self?.transcriptionService.appendPCM16Mono16k(pcmData)
            }
            .store(in: &cancellables)

        transcriptionService.transcriptPublisher
            .sink { [weak self] text in
                guard let self else { return }
                let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.transcriptSubject.send(normalized)
            }
            .store(in: &cancellables)

        transcriptionService.finalTranscriptPublisher
            .sink { [weak self] finalText in
                guard let self else { return }
                let normalized = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { return }
                guard normalized != self.lastFinalTranscriptSentToDisplay else { return }

                self.controller.sendTextToHallidayDisplay(normalized)
                self.lastFinalTranscriptSentToDisplay = normalized
            }
            .store(in: &cancellables)
    }
}
