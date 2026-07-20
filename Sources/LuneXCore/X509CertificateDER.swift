import Foundation

enum X509CertificateDERError: Error, Equatable, Sendable {
    case invalidStructure
    case unsupportedSignatureAlgorithm
}

struct X509CertificateEnvelope: Equatable, Sendable {
    private static let sha256WithRSAAlgorithmIdentifier = Data([
        0x30, 0x0D,
        0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B,
        0x05, 0x00
    ])

    let toBeSigned: Data
    let signature: Data

    static func parse(_ der: Data) throws -> Self {
        let bytes = [UInt8](der)
        let outer = try readElement(bytes, at: 0, expectedTag: 0x30)
        guard outer.nextOffset == bytes.count else {
            throw X509CertificateDERError.invalidStructure
        }

        let toBeSigned = try readElement(bytes, at: outer.contentOffset, expectedTag: 0x30)
        let algorithm = try readElement(bytes, at: toBeSigned.nextOffset, expectedTag: 0x30)
        let signature = try readElement(bytes, at: algorithm.nextOffset, expectedTag: 0x03)
        guard signature.nextOffset == outer.nextOffset,
              signature.contentLength > 1,
              bytes[signature.contentOffset] == 0 else {
            throw X509CertificateDERError.invalidStructure
        }
        guard Data(bytes[algorithm.encodedRange]) == sha256WithRSAAlgorithmIdentifier else {
            throw X509CertificateDERError.unsupportedSignatureAlgorithm
        }

        let signatureStart = signature.contentOffset + 1
        return Self(
            toBeSigned: Data(bytes[toBeSigned.encodedRange]),
            signature: Data(bytes[signatureStart..<signature.nextOffset])
        )
    }

    private static func readElement(
        _ bytes: [UInt8],
        at offset: Int,
        expectedTag: UInt8
    ) throws -> Element {
        guard offset >= 0, offset + 2 <= bytes.count, bytes[offset] == expectedTag else {
            throw X509CertificateDERError.invalidStructure
        }
        let firstLength = bytes[offset + 1]
        let contentOffset: Int
        let contentLength: Int
        if firstLength & 0x80 == 0 {
            contentOffset = offset + 2
            contentLength = Int(firstLength)
        } else {
            let octetCount = Int(firstLength & 0x7F)
            guard (1...4).contains(octetCount),
                  offset + 2 + octetCount <= bytes.count,
                  bytes[offset + 2] != 0 else {
                throw X509CertificateDERError.invalidStructure
            }
            var length = 0
            for byte in bytes[(offset + 2)..<(offset + 2 + octetCount)] {
                guard length <= (Int.max - Int(byte)) / 256 else {
                    throw X509CertificateDERError.invalidStructure
                }
                length = length * 256 + Int(byte)
            }
            guard length >= 0x80 else {
                throw X509CertificateDERError.invalidStructure
            }
            contentOffset = offset + 2 + octetCount
            contentLength = length
        }
        guard contentLength >= 0,
              contentLength <= bytes.count,
              contentOffset <= bytes.count - contentLength else {
            throw X509CertificateDERError.invalidStructure
        }
        return Element(
            encodedRange: offset..<(contentOffset + contentLength),
            contentOffset: contentOffset,
            contentLength: contentLength,
            nextOffset: contentOffset + contentLength
        )
    }

    private struct Element {
        let encodedRange: Range<Int>
        let contentOffset: Int
        let contentLength: Int
        let nextOffset: Int
    }
}
