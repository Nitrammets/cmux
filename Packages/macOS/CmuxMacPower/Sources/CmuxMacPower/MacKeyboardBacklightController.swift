/// High-level control for the Mac keyboard backlight.
///
/// The controller targets the first reported backlit keyboard id for v1 and
/// keeps clamping/unsupported policy outside the private CoreBrightness client.
public struct MacKeyboardBacklightController: Sendable {
    private let client: any MacKeyboardBacklightClient

    /// Creates a keyboard backlight controller with an injectable client.
    public init(client: any MacKeyboardBacklightClient = CoreBrightnessKeyboardBacklightClient()) {
        self.client = client
    }

    /// Reads the first backlit keyboard's brightness.
    public func status() -> MacKeyboardBacklightStatus {
        guard let keyboardID = client.backlightKeyboardIDs().first,
              let brightness = client.brightness(forKeyboard: keyboardID) else {
            return unsupportedStatus
        }
        return MacKeyboardBacklightStatus(supported: true, brightness: Self.clamp(brightness))
    }

    /// Sets the first backlit keyboard's brightness, clamped to `0...1`.
    ///
    /// - Parameter brightness: The requested normalized brightness.
    /// - Returns: The post-write keyboard backlight status.
    public func setBrightness(_ brightness: Float) -> MacKeyboardBacklightStatus {
        guard let keyboardID = client.backlightKeyboardIDs().first else {
            return unsupportedStatus
        }
        _ = client.setBrightness(Self.clamp(brightness), forKeyboard: keyboardID)
        return status()
    }

    private var unsupportedStatus: MacKeyboardBacklightStatus {
        MacKeyboardBacklightStatus(supported: false, brightness: 0)
    }

    private static func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
