// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import Combine
import Speech
import AVFoundation

final class PCMTranscriptionService {
    private let transcriptSubject = CurrentValueSubject<String, Never>("")
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var transcriptPublisher: AnyPublisher<String, Never> {
        transcriptSubject.eraseToAnyPublisher()
    }

    var finalTranscriptPublisher: AnyPublisher<String, Never> {
        finalTranscriptSubject.eraseToAnyPublisher()
    }

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }

            switch status {
            case .authorized:
                DispatchQueue.main.async {
                    self.startRecognitionSession()
                }
            case .denied:
                self.transcriptSubject.send("Speech permission denied")
            case .restricted:
                self.transcriptSubject.send("Speech recognition restricted on this device")
            case .notDetermined:
                self.transcriptSubject.send("Speech permission not determined")
            @unknown default:
                self.transcriptSubject.send("Speech recognition unavailable")
            }
        }
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    func appendPCM16Mono16k(_ pcmLE: Data) {
        guard let request, let audioFormat else { return }
        guard pcmLE.count >= 2 else { return }

        let sampleCount = pcmLE.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        guard let dst = buffer.int16ChannelData?.pointee else { return }
        pcmLE.withUnsafeBytes { raw in
            guard let src = raw.bindMemory(to: Int16.self).baseAddress else { return }
            dst.assign(from: src, count: sampleCount)
        }

        request.append(buffer)
    }

    private func startRecognitionSession() {
        stop()

        guard let recognizer, recognizer.isAvailable else {
            transcriptSubject.send("Speech recognizer unavailable")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.transcriptSubject.send(text)
                if result.isFinal {
                    self.finalTranscriptSubject.send(text)
                    self.transcriptSubject.send("")
                    DispatchQueue.main.async {
                        self.startRecognitionSession()
                    }
                    return
                }
            }

            if error != nil {
                // Restart the session so streaming can continue after recoverable errors.
                self.startRecognitionSession()
            }
        }
    }
}
