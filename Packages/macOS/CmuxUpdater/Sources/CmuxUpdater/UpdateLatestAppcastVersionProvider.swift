public import Foundation

/// Best-effort reader for the first update version advertised by a Sparkle appcast feed.
public actor UpdateLatestAppcastVersionProvider {
    public typealias Transport = @Sendable (URL) async throws -> Data

    private let allowsNetwork: Bool
    private let transport: Transport

    public init(allowsNetwork: Bool = true) {
        self.init(allowsNetwork: allowsNetwork, transport: Self.urlSessionTransport)
    }

    public init(allowsNetwork: Bool = true, transport: @escaping Transport) {
        self.allowsNetwork = allowsNetwork
        self.transport = transport
    }

    /// Returns the first item version in `feedURLString`, or `nil` if the feed cannot be read.
    public func latestVersion(feedURLString: String) async -> String? {
        guard allowsNetwork,
              let url = URL(string: feedURLString),
              let data = try? await transport(url) else {
            return nil
        }
        return Self.parseLatestVersion(from: String(decoding: data, as: UTF8.self))
    }

    public static func parseLatestVersion(from appcast: String) -> String? {
        let item = firstMatch(in: appcast, pattern: #"<item\b[\s\S]*?</item>"#) ?? appcast
        let patterns = [
            #"sparkle:shortVersionString="([^"]+)""#,
            #"<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>"#,
            #"sparkle:version="([^"]+)""#,
            #"<sparkle:version>([^<]+)</sparkle:version>"#,
        ]
        for pattern in patterns {
            if let version = firstCapture(in: item, pattern: pattern) {
                let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else { return nil }
        return String(text[matchRange])
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func urlSessionTransport(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
