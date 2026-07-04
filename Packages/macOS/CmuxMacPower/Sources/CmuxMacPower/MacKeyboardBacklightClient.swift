/// Seam over keyboard-backlight APIs used by ``MacKeyboardBacklightController``.
///
/// The production implementation uses a runtime-loaded private framework, while
/// tests inject a fake that never touches CoreBrightness.
public protocol MacKeyboardBacklightClient: Sendable {
    /// Returns keyboard ids that expose a backlight.
    func backlightKeyboardIDs() -> [UInt64]

    /// Reads one keyboard's brightness, normalized to `0...1`.
    func brightness(forKeyboard keyboardID: UInt64) -> Float?

    /// Sets one keyboard's brightness.
    @discardableResult
    func setBrightness(_ brightness: Float, forKeyboard keyboardID: UInt64) -> Bool
}
