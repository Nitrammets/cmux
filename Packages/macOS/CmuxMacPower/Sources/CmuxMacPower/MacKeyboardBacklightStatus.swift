/// A snapshot of the built-in keyboard backlight brightness.
///
/// `supported` is false when CoreBrightness is unavailable, the private class
/// is absent, or no backlit keyboard id is reported.
public struct MacKeyboardBacklightStatus: Sendable, Equatable {
    /// Whether a keyboard backlight is available.
    public let supported: Bool
    /// The keyboard backlight brightness normalized to `0...1`.
    public let brightness: Float

    /// Creates a keyboard backlight status snapshot.
    public init(supported: Bool, brightness: Float) {
        self.supported = supported
        self.brightness = brightness
    }

    /// JSON-serializable wire form for the mobile RPC backlight methods.
    public var jsonObject: [String: Any] {
        [
            "supported": supported,
            "brightness": brightness,
        ]
    }
}
