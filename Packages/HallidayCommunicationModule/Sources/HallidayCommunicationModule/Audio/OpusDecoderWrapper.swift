// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation
import HallidayObjC

public final class OpusDecoderWrapper {
    private var dec: OpaquePointer?
    private let sampleRate = 16_000
    private let channels = 1

    public init?() {
        var err: Int32 = 0
        dec = opus_decoder_create(Int32(sampleRate), Int32(channels), &err)
        guard err == OPUS_OK, dec != nil else { return nil }
    }

    deinit {
        if let dec { opus_decoder_destroy(dec) }
    }

    public func decode(packet: Data, maxFrameSamples: Int = 320) -> [Int16]? {
        guard let dec = dec else { return nil }

        var pcm = [Int16](repeating: 0, count: maxFrameSamples * channels)

        let decodedSamples: Int32 = packet.withUnsafeBytes { pktPtr in
            guard let base = pktPtr.bindMemory(to: UInt8.self).baseAddress else {
                return Int32(OPUS_BAD_ARG)
            }
            return opus_decode(dec, base, Int32(packet.count), &pcm, Int32(maxFrameSamples), 0)
        }

        guard decodedSamples > 0 else { return nil }
        return Array(pcm.prefix(Int(decodedSamples) * channels))
    }
}

extension Array where Element == Int16 {
    public func toLittleEndianData() -> Data {
        var le = self.map { $0.littleEndian }
        return Data(bytes: &le, count: le.count * MemoryLayout<Int16>.size)
    }
}
