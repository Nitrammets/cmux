/// Seam over the system audio device APIs used by ``MacAudioController``.
///
/// The protocol stays deliberately narrow so controller policy (fallback order,
/// clamping, and unsupported detection) is unit-testable without touching the
/// real default output device.
public protocol MacAudioDeviceClient: Sendable {
    /// Returns the current default output device id, or `nil` when CoreAudio
    /// cannot provide one.
    func defaultOutputDeviceID() -> UInt32?

    /// Reads the virtual main volume for the output device, normalized to `0...1`.
    func readVirtualMainVolume(deviceID: UInt32) -> Float?

    /// Returns whether the virtual main volume can be changed.
    func isVirtualMainVolumeSettable(deviceID: UInt32) -> Bool

    /// Sets the virtual main volume.
    @discardableResult
    func setVirtualMainVolume(_ volume: Float, deviceID: UInt32) -> Bool

    /// Reads one output channel's scalar volume, normalized to `0...1`.
    func readChannelVolume(deviceID: UInt32, channel: UInt32) -> Float?

    /// Returns whether one output channel's scalar volume can be changed.
    func isChannelVolumeSettable(deviceID: UInt32, channel: UInt32) -> Bool

    /// Sets one output channel's scalar volume.
    @discardableResult
    func setChannelVolume(_ volume: Float, deviceID: UInt32, channel: UInt32) -> Bool

    /// Reads the output mute state.
    func readMute(deviceID: UInt32) -> Bool?

    /// Returns whether the output mute state can be changed.
    func isMuteSettable(deviceID: UInt32) -> Bool

    /// Sets the output mute state.
    @discardableResult
    func setMute(_ muted: Bool, deviceID: UInt32) -> Bool
}
