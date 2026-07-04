import AudioToolbox

/// CoreAudio-backed ``MacAudioDeviceClient`` for the default output device.
public struct SystemMacAudioDeviceClient: MacAudioDeviceClient {
    /// Creates a system CoreAudio device client.
    public init() {}

    /// Returns the current default output device id, or `nil` when CoreAudio
    /// cannot provide one.
    public func defaultOutputDeviceID() -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return UInt32(deviceID)
    }

    /// Reads the virtual main volume for the output device, normalized to `0...1`.
    public func readVirtualMainVolume(deviceID: UInt32) -> Float? {
        readFloat(deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain)
    }

    /// Returns whether the virtual main volume can be changed.
    public func isVirtualMainVolumeSettable(deviceID: UInt32) -> Bool {
        isSettable(deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain)
    }

    /// Sets the virtual main volume.
    @discardableResult
    public func setVirtualMainVolume(_ volume: Float, deviceID: UInt32) -> Bool {
        setFloat(volume, deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain)
    }

    /// Reads one output channel's scalar volume, normalized to `0...1`.
    public func readChannelVolume(deviceID: UInt32, channel: UInt32) -> Float? {
        readFloat(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: channel)
    }

    /// Returns whether one output channel's scalar volume can be changed.
    public func isChannelVolumeSettable(deviceID: UInt32, channel: UInt32) -> Bool {
        isSettable(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: channel)
    }

    /// Sets one output channel's scalar volume.
    @discardableResult
    public func setChannelVolume(_ volume: Float, deviceID: UInt32, channel: UInt32) -> Bool {
        setFloat(volume, deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: channel)
    }

    /// Reads the output mute state.
    public func readMute(deviceID: UInt32) -> Bool? {
        var muted = UInt32(0)
        guard readValue(&muted, deviceID: deviceID, selector: kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain) else {
            return nil
        }
        return muted != 0
    }

    /// Returns whether the output mute state can be changed.
    public func isMuteSettable(deviceID: UInt32) -> Bool {
        isSettable(deviceID: deviceID, selector: kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain)
    }

    /// Sets the output mute state.
    @discardableResult
    public func setMute(_ muted: Bool, deviceID: UInt32) -> Bool {
        var value: UInt32 = muted ? 1 : 0
        return setValue(&value, deviceID: deviceID, selector: kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain)
    }

    private func readFloat(deviceID: UInt32, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Float? {
        var value = Float(0)
        guard readValue(&value, deviceID: deviceID, selector: selector, element: element) else { return nil }
        return value
    }

    private func setFloat(_ value: Float, deviceID: UInt32, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Bool {
        var value = value
        return setValue(&value, deviceID: deviceID, selector: selector, element: element)
    }

    private func readValue<T>(_ value: inout T, deviceID: UInt32, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Bool {
        var address = propertyAddress(selector: selector, element: element)
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(
            AudioObjectID(deviceID),
            &address,
            0,
            nil,
            &size,
            &value
        ) == noErr
    }

    private func setValue<T>(_ value: inout T, deviceID: UInt32, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Bool {
        var address = propertyAddress(selector: selector, element: element)
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectSetPropertyData(
            AudioObjectID(deviceID),
            &address,
            0,
            nil,
            size,
            &value
        ) == noErr
    }

    private func isSettable(deviceID: UInt32, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Bool {
        var address = propertyAddress(selector: selector, element: element)
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(AudioObjectID(deviceID), &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func propertyAddress(selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }
}
