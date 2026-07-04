/// The connected Mac's keyboard backlight brightness.
///
/// Mirrors the Mac's `mac.keyboard_backlight.status` and
/// `mac.keyboard_backlight.set` result
/// (`CmuxMacPower.MacKeyboardBacklightStatus`).
public struct MobileMacKeyboardBacklightStatus: Decodable, Sendable, Equatable {
    /// Whether the Mac reports a backlit keyboard.
    public let supported: Bool

    /// The keyboard backlight brightness normalized to `0...1`.
    public let brightness: Float

    private enum CodingKeys: String, CodingKey {
        case supported
        case brightness
    }

    /// Decodes a keyboard backlight status snapshot from the Mac wire payload.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        supported = (try container.decodeIfPresent(Bool.self, forKey: .supported)) ?? false
        brightness = (try container.decodeIfPresent(Float.self, forKey: .brightness)) ?? 0
    }

    /// Creates a keyboard backlight status snapshot for tests and local UI state.
    public init(supported: Bool, brightness: Float) {
        self.supported = supported
        self.brightness = brightness
    }
}
