import Foundation

enum NetworkFramePrefixWidth: Int, Equatable, Sendable {
    case uint16 = 2
    case uint32 = 4
}

enum NetworkFrameDecodingError: Error, Equatable, Sendable {
    case invalidMaximumLength
    case emptyFrame
    case declaredLengthExceedsLimit(declared: Int, maximum: Int)
    case truncatedFrame
    case bufferedDataExceedsLimit
}

struct BoundedLengthPrefixedFrameDecoder: Sendable {
    private let prefixWidth: NetworkFramePrefixWidth
    private let maximumFrameLength: Int
    private var buffer = Data()

    init(
        prefixWidth: NetworkFramePrefixWidth,
        maximumFrameLength: Int
    ) throws {
        guard maximumFrameLength > 0 else {
            throw NetworkFrameDecodingError.invalidMaximumLength
        }
        self.prefixWidth = prefixWidth
        self.maximumFrameLength = maximumFrameLength
    }

    mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        let prefixLength = prefixWidth.rawValue

        while buffer.count >= prefixLength {
            let declaredLength = decodeLength(from: buffer.prefix(prefixLength))
            guard declaredLength > 0 else {
                throw NetworkFrameDecodingError.emptyFrame
            }
            guard declaredLength <= maximumFrameLength else {
                throw NetworkFrameDecodingError.declaredLengthExceedsLimit(
                    declared: declaredLength,
                    maximum: maximumFrameLength
                )
            }
            let totalLength = prefixLength + declaredLength
            guard buffer.count >= totalLength else { break }
            let payloadStart = buffer.index(buffer.startIndex, offsetBy: prefixLength)
            let payloadEnd = buffer.index(payloadStart, offsetBy: declaredLength)
            frames.append(Data(buffer[payloadStart..<payloadEnd]))
            buffer.removeFirst(totalLength)
        }

        guard buffer.count <= prefixLength + maximumFrameLength else {
            throw NetworkFrameDecodingError.bufferedDataExceedsLimit
        }
        return frames
    }

    mutating func finish() throws {
        guard buffer.isEmpty else {
            throw NetworkFrameDecodingError.truncatedFrame
        }
    }

    var bufferedByteCount: Int {
        buffer.count
    }

    private func decodeLength(from bytes: Data.SubSequence) -> Int {
        bytes.reduce(0) { partial, byte in
            (partial << 8) | Int(byte)
        }
    }
}
