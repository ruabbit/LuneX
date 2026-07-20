import Foundation

struct RTSPParserLimits: Equatable, Sendable {
    var maximumMessageBytes: Int
    var maximumHeaderBytes: Int
    var maximumBodyBytes: Int
    var maximumStartLineBytes: Int
    var maximumHeaderCount: Int
    var maximumHeaderNameBytes: Int
    var maximumHeaderValueBytes: Int

    static let moonlight = RTSPParserLimits(
        maximumMessageBytes: 1_048_576,
        maximumHeaderBytes: 65_536,
        maximumBodyBytes: 983_040,
        maximumStartLineBytes: 8_192,
        maximumHeaderCount: 128,
        maximumHeaderNameBytes: 128,
        maximumHeaderValueBytes: 8_192
    )
}

enum RTSPMessageError: Error, Equatable, Sendable {
    case incomplete
    case messageTooLarge
    case headerSectionTooLarge
    case bodyTooLarge
    case startLineTooLarge
    case tooManyHeaders
    case malformedStartLine
    case unsupportedVersion
    case invalidMethod
    case invalidTarget
    case invalidStatusCode
    case invalidHeaderName
    case invalidHeaderValue
    case duplicateContentLength
    case invalidContentLength
    case contentLengthMismatch
    case trailingBytes
}

struct RTSPHeader: Equatable, Sendable {
    var name: String
    var value: String
}

struct RTSPRequest: Equatable, Sendable {
    var method: String
    var target: String
    var version: String = "RTSP/1.0"
    var headers: [RTSPHeader] = []
    var body = Data()

    func headerValues(named name: String) -> [String] {
        headers.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            .map(\.value)
    }
}

struct RTSPResponse: Equatable, Sendable {
    var version: String = "RTSP/1.0"
    var statusCode: Int
    var reasonPhrase: String
    var headers: [RTSPHeader] = []
    var body = Data()

    func headerValues(named name: String) -> [String] {
        headers.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            .map(\.value)
    }
}

enum RTSPMessage: Equatable, Sendable {
    case request(RTSPRequest)
    case response(RTSPResponse)

    var headers: [RTSPHeader] {
        switch self {
        case let .request(request): request.headers
        case let .response(response): response.headers
        }
    }

    var body: Data {
        switch self {
        case let .request(request): request.body
        case let .response(response): response.body
        }
    }
}

struct DecodedRTSPMessage: Equatable, Sendable {
    var message: RTSPMessage
    var consumedBytes: Int
}

enum RTSPMessageCodec {
    private static let headerTerminator: [UInt8] = [13, 10, 13, 10]
    private static let lineTerminator: [UInt8] = [13, 10]

    static func decodePrefix(
        _ data: Data,
        limits: RTSPParserLimits = .moonlight
    ) throws -> DecodedRTSPMessage? {
        let bytes = [UInt8](data)
        guard let headerEnd = firstIndex(of: headerTerminator, in: bytes) else {
            if bytes.count > limits.maximumHeaderBytes {
                throw RTSPMessageError.headerSectionTooLarge
            }
            return nil
        }
        let bodyStart = headerEnd + headerTerminator.count
        guard bodyStart <= limits.maximumHeaderBytes else {
            throw RTSPMessageError.headerSectionTooLarge
        }

        let headerBytes = Array(bytes[..<headerEnd])
        let lines = split(headerBytes, separator: lineTerminator)
        guard let startLine = lines.first, !startLine.isEmpty else {
            throw RTSPMessageError.malformedStartLine
        }
        guard startLine.count <= limits.maximumStartLineBytes else {
            throw RTSPMessageError.startLineTooLarge
        }
        guard lines.count - 1 <= limits.maximumHeaderCount else {
            throw RTSPMessageError.tooManyHeaders
        }

        let headers = try lines.dropFirst().map { try parseHeader($0, limits: limits) }
        let contentLength = try parseContentLength(headers)
        guard contentLength <= limits.maximumBodyBytes else {
            throw RTSPMessageError.bodyTooLarge
        }
        let messageLength = bodyStart + contentLength
        guard messageLength <= limits.maximumMessageBytes else {
            throw RTSPMessageError.messageTooLarge
        }
        guard bytes.count >= messageLength else { return nil }
        let body = Data(bytes[bodyStart..<messageLength])
        let message = try parseStartLine(startLine, headers: headers, body: body)
        return DecodedRTSPMessage(message: message, consumedBytes: messageLength)
    }

    static func decodeExact(
        _ data: Data,
        limits: RTSPParserLimits = .moonlight
    ) throws -> RTSPMessage {
        guard let decoded = try decodePrefix(data, limits: limits) else {
            throw RTSPMessageError.incomplete
        }
        guard decoded.consumedBytes == data.count else {
            throw RTSPMessageError.trailingBytes
        }
        return decoded.message
    }

    static func serialize(
        _ message: RTSPMessage,
        limits: RTSPParserLimits = .moonlight
    ) throws -> Data {
        let startLine: String
        let headers: [RTSPHeader]
        let body: Data
        switch message {
        case let .request(request):
            try validateVersion(request.version)
            try validateMethod(request.method)
            try validateTarget(request.target)
            startLine = "\(request.method) \(request.target) \(request.version)"
            headers = request.headers
            body = request.body
        case let .response(response):
            try validateVersion(response.version)
            guard (100...999).contains(response.statusCode) else {
                throw RTSPMessageError.invalidStatusCode
            }
            try validateReasonPhrase(response.reasonPhrase)
            startLine = "\(response.version) \(response.statusCode) \(response.reasonPhrase)"
            headers = response.headers
            body = response.body
        }

        guard startLine.utf8.count <= limits.maximumStartLineBytes else {
            throw RTSPMessageError.startLineTooLarge
        }
        guard headers.count <= limits.maximumHeaderCount else {
            throw RTSPMessageError.tooManyHeaders
        }
        let declaredLength = try parseContentLength(headers)
        guard declaredLength == body.count else {
            throw RTSPMessageError.contentLengthMismatch
        }
        guard body.count <= limits.maximumBodyBytes else {
            throw RTSPMessageError.bodyTooLarge
        }

        var wire = Data(startLine.utf8)
        wire.append(contentsOf: lineTerminator)
        for header in headers {
            try validateHeader(header, limits: limits)
            wire.append(contentsOf: header.name.utf8)
            wire.append(contentsOf: [58, 32])
            wire.append(contentsOf: header.value.utf8)
            wire.append(contentsOf: lineTerminator)
        }
        wire.append(contentsOf: lineTerminator)
        guard wire.count <= limits.maximumHeaderBytes else {
            throw RTSPMessageError.headerSectionTooLarge
        }
        guard wire.count + body.count <= limits.maximumMessageBytes else {
            throw RTSPMessageError.messageTooLarge
        }
        wire.append(body)
        return wire
    }

    private static func parseStartLine(
        _ bytes: [UInt8],
        headers: [RTSPHeader],
        body: Data
    ) throws -> RTSPMessage {
        guard let line = String(bytes: bytes, encoding: .ascii) else {
            throw RTSPMessageError.malformedStartLine
        }
        if line.hasPrefix("RTSP/") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, let statusCode = Int(parts[1]) else {
                throw RTSPMessageError.malformedStartLine
            }
            let version = String(parts[0])
            let reason = String(parts[2])
            try validateVersion(version)
            guard (100...999).contains(statusCode) else {
                throw RTSPMessageError.invalidStatusCode
            }
            try validateReasonPhrase(reason)
            return .response(RTSPResponse(
                version: version,
                statusCode: statusCode,
                reasonPhrase: reason,
                headers: headers,
                body: body
            ))
        }

        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw RTSPMessageError.malformedStartLine
        }
        let method = String(parts[0])
        let target = String(parts[1])
        let version = String(parts[2])
        try validateMethod(method)
        try validateTarget(target)
        try validateVersion(version)
        return .request(RTSPRequest(
            method: method,
            target: target,
            version: version,
            headers: headers,
            body: body
        ))
    }

    private static func parseHeader(
        _ bytes: [UInt8],
        limits: RTSPParserLimits
    ) throws -> RTSPHeader {
        guard let separator = bytes.firstIndex(of: 58) else {
            throw RTSPMessageError.invalidHeaderName
        }
        let nameBytes = Array(bytes[..<separator])
        var valueBytes = Array(bytes[(separator + 1)...])
        while valueBytes.first == 32 || valueBytes.first == 9 { valueBytes.removeFirst() }
        while valueBytes.last == 32 || valueBytes.last == 9 { valueBytes.removeLast() }
        guard let name = String(bytes: nameBytes, encoding: .ascii) else {
            throw RTSPMessageError.invalidHeaderName
        }
        guard let value = String(bytes: valueBytes, encoding: .ascii) else {
            throw RTSPMessageError.invalidHeaderValue
        }
        let header = RTSPHeader(name: name, value: value)
        try validateHeader(header, limits: limits)
        return header
    }

    private static func parseContentLength(_ headers: [RTSPHeader]) throws -> Int {
        let values = headers.filter {
            $0.name.caseInsensitiveCompare("Content-Length") == .orderedSame
        }.map(\.value)
        guard values.count <= 1 else {
            throw RTSPMessageError.duplicateContentLength
        }
        guard let value = values.first else { return 0 }
        guard !value.isEmpty,
              value.utf8.allSatisfy({ (48...57).contains($0) }),
              let length = Int(value) else {
            throw RTSPMessageError.invalidContentLength
        }
        return length
    }

    private static func validateHeader(
        _ header: RTSPHeader,
        limits: RTSPParserLimits
    ) throws {
        let nameBytes = [UInt8](header.name.utf8)
        guard !nameBytes.isEmpty,
              nameBytes.count <= limits.maximumHeaderNameBytes,
              nameBytes.allSatisfy(isTokenByte) else {
            throw RTSPMessageError.invalidHeaderName
        }
        let valueBytes = [UInt8](header.value.utf8)
        guard valueBytes.count <= limits.maximumHeaderValueBytes,
              valueBytes.allSatisfy({ $0 == 9 || (32...126).contains($0) }) else {
            throw RTSPMessageError.invalidHeaderValue
        }
    }

    private static func validateVersion(_ version: String) throws {
        guard version == "RTSP/1.0" else {
            throw RTSPMessageError.unsupportedVersion
        }
    }

    private static func validateMethod(_ method: String) throws {
        let bytes = [UInt8](method.utf8)
        guard !bytes.isEmpty, bytes.allSatisfy(isTokenByte) else {
            throw RTSPMessageError.invalidMethod
        }
    }

    private static func validateTarget(_ target: String) throws {
        let bytes = [UInt8](target.utf8)
        guard !bytes.isEmpty, bytes.allSatisfy({ (33...126).contains($0) }) else {
            throw RTSPMessageError.invalidTarget
        }
    }

    private static func validateReasonPhrase(_ reason: String) throws {
        guard reason.utf8.allSatisfy({ $0 == 9 || (32...126).contains($0) }) else {
            throw RTSPMessageError.malformedStartLine
        }
    }

    private static func isTokenByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 33, 35...39, 42...43, 45...46, 48...57, 65...90, 94...122, 124, 126:
            return true
        default:
            return false
        }
    }

    private static func firstIndex(of needle: [UInt8], in bytes: [UInt8]) -> Int? {
        guard !needle.isEmpty, bytes.count >= needle.count else { return nil }
        for index in 0...(bytes.count - needle.count) {
            if bytes[index..<(index + needle.count)].elementsEqual(needle) {
                return index
            }
        }
        return nil
    }

    private static func split(_ bytes: [UInt8], separator: [UInt8]) -> [[UInt8]] {
        guard !bytes.isEmpty else { return [[]] }
        var result: [[UInt8]] = []
        var start = 0
        var index = 0
        while index + separator.count <= bytes.count {
            if bytes[index..<(index + separator.count)].elementsEqual(separator) {
                result.append(Array(bytes[start..<index]))
                index += separator.count
                start = index
            } else {
                index += 1
            }
        }
        result.append(Array(bytes[start...]))
        return result
    }
}
