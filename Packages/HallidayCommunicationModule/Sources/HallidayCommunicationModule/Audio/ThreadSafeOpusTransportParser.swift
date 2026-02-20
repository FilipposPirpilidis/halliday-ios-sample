// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation

public final class ThreadSafeOpusTransportParser {
    private var buffer = Data()
    private let q = DispatchQueue(label: "halliday.opus.parser.serial")

    private let headerSize = 8
    private let maxPayloadLen: UInt32 = 2000

    public init() {}

    public func push(_ chunk: Data) -> [Data] {
        q.sync {
            buffer.append(chunk)
            var packets: [Data] = []

            while true {
                if buffer.count < headerSize { break }

                let (beLen, leLen): (UInt32, UInt32) = buffer.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count >= 4 else {
                        return (0, 0)
                    }
                    let b0 = UInt32(base[0])
                    let b1 = UInt32(base[1])
                    let b2 = UInt32(base[2])
                    let b3 = UInt32(base[3])
                    let be = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
                    let le = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
                    return (be, le)
                }

                let len: UInt32
                if beLen > 0, beLen <= maxPayloadLen {
                    len = beLen
                } else if leLen > 0, leLen <= maxPayloadLen {
                    len = leLen
                } else {
                    buffer.removeFirst(1)
                    continue
                }

                let frameSizeU32 = UInt32(headerSize) &+ len
                let frameSize = Int(frameSizeU32)

                if frameSize < headerSize {
                    buffer.removeFirst(1)
                    continue
                }

                if buffer.count < frameSize { break }

                let payloadLen = frameSize - headerSize
                if payloadLen <= 0 {
                    buffer.removeFirst(1)
                    continue
                }

                let payload: Data = buffer.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress, raw.count >= frameSize else { return Data() }
                    return Data(bytes: base.advanced(by: headerSize), count: payloadLen)
                }

                if payload.isEmpty {
                    buffer.removeFirst(1)
                    continue
                }

                buffer.removeFirst(frameSize)
                packets.append(payload)
            }

            return packets
        }
    }
}
