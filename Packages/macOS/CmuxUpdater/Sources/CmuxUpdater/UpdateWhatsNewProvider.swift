public import Foundation

/// Loads and parses short changelog bullets for the update-ready toast.
///
/// Fetching is best-effort and cached per staged version: failures return an empty list so the
/// toast can render immediately and simply omit the "what's new" section.
public actor UpdateWhatsNewProvider {
    public typealias Transport = @Sendable (URL) async throws -> Data

    private static let changelogURL = URL(string: "https://raw.githubusercontent.com/manaflow-ai/cmux/main/CHANGELOG.md")!

    private let allowsNetwork: Bool
    private let transport: Transport
    private var cache: [String: [String]] = [:]

    public init(allowsNetwork: Bool = true) {
        self.init(allowsNetwork: allowsNetwork, transport: Self.urlSessionTransport)
    }

    public init(allowsNetwork: Bool = true, transport: @escaping Transport) {
        self.allowsNetwork = allowsNetwork
        self.transport = transport
    }

    /// Returns up to three plain-text bullets for `version`, or an empty list on any failure.
    public func bullets(for version: String) async -> [String] {
        let version = Self.normalizeVersion(version)
        guard !version.isEmpty else { return [] }
        if let cached = cache[version] { return cached }

        #if DEBUG
        if let injected = Self.injectedUITestBullets() {
            cache[version] = injected
            return injected
        }
        #endif

        guard allowsNetwork else {
            cache[version] = []
            return []
        }

        do {
            let data = try await transport(Self.changelogURL)
            let text = String(decoding: data, as: UTF8.self)
            let bullets = Self.parseBullets(for: version, in: text)
            cache[version] = bullets
            return bullets
        } catch {
            cache[version] = []
            return []
        }
    }

    /// Parses the top-level markdown bullets from a `## [version] - date` changelog section.
    public static func parseBullets(for version: String, in changelog: String) -> [String] {
        let version = normalizeVersion(version)
        guard !version.isEmpty else { return [] }

        let headings = ["## [\(version)]", "## [v\(version)]"]
        let lines = changelog.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { line in
            headings.contains { line.hasPrefix($0) }
        }) else { return [] }

        var bullets: [String] = []
        for line in lines.dropFirst(start + 1) {
            if line.hasPrefix("## ") { break }
            guard line.hasPrefix("- ") else { continue }
            let plain = stripMarkdown(String(line.dropFirst(2)))
            if !plain.isEmpty {
                bullets.append(plain)
                if bullets.count == 3 { break }
            }
        }
        return bullets
    }

    private static func normalizeVersion(_ version: String) -> String {
        version.trimmingCharacters(in: .whitespacesAndNewlines).dropPrefix("v")
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        let linkPattern = #"\[([^\]]+)\]\([^)]+\)"#
        result = result.replacingOccurrences(of: linkPattern, with: "$1", options: .regularExpression)
        for marker in ["**", "__", "`", "*", "_"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    #if DEBUG
    private static func injectedUITestBullets() -> [String]? {
        let raw = ProcessInfo.processInfo.environment["CMUX_UI_TEST_UPDATE_WHATS_NEW"] ?? ""
        guard !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(parts.prefix(upTo: min(3, parts.count)))
    }
    #endif

    private static func urlSessionTransport(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

private extension StringProtocol {
    func dropPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : String(self)
    }
}
