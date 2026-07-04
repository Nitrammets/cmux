/// High-level audio control for the Mac's default output device.
///
/// The controller owns all policy around clamping, CoreAudio fallback order, and
/// unsupported devices; the injected ``MacAudioDeviceClient`` only performs
/// narrow system reads and writes.
public struct MacAudioController: Sendable {
    private let client: any MacAudioDeviceClient

    /// Creates an audio controller with an injectable CoreAudio client.
    public init(client: any MacAudioDeviceClient = SystemMacAudioDeviceClient()) {
        self.client = client
    }

    /// Reads the current default output volume and mute status.
    public func status() -> MacAudioStatus {
        guard let deviceID = client.defaultOutputDeviceID(),
              let volumeControl = volumeControl(deviceID: deviceID) else {
            return unsupportedStatus
        }
        return MacAudioStatus(
            supported: true,
            volume: volumeControl.volume,
            muted: client.readMute(deviceID: deviceID) ?? false,
            volumeSettable: volumeControl.settable
        )
    }

    /// Sets the default output volume, clamped to `0...1`, then returns a fresh status.
    ///
    /// - Parameter volume: The requested normalized volume.
    /// - Returns: The post-write audio status, or unsupported when no output
    ///   volume control is available.
    public func setVolume(_ volume: Float) -> MacAudioStatus {
        guard let deviceID = client.defaultOutputDeviceID(),
              let volumeControl = volumeControl(deviceID: deviceID) else {
            return unsupportedStatus
        }
        let clamped = Self.clamp(volume)
        switch volumeControl.kind {
        case .virtualMain:
            if volumeControl.settable {
                _ = client.setVirtualMainVolume(clamped, deviceID: deviceID)
            }
        case let .channels(channels):
            if volumeControl.settable {
                for channel in channels {
                    _ = client.setChannelVolume(clamped, deviceID: deviceID, channel: channel)
                }
            }
        }
        return status()
    }

    /// Sets the default output mute state, then returns a fresh status.
    ///
    /// - Parameter muted: Whether the default output device should be muted.
    /// - Returns: The post-write audio status, or unsupported when no output
    ///   volume control is available.
    public func setMuted(_ muted: Bool) -> MacAudioStatus {
        guard let deviceID = client.defaultOutputDeviceID(),
              volumeControl(deviceID: deviceID) != nil else {
            return unsupportedStatus
        }
        if client.isMuteSettable(deviceID: deviceID) {
            _ = client.setMute(muted, deviceID: deviceID)
        }
        return status()
    }

    private var unsupportedStatus: MacAudioStatus {
        MacAudioStatus(supported: false, volume: 0, muted: false, volumeSettable: false)
    }

    private func volumeControl(deviceID: UInt32) -> VolumeControl? {
        if let volume = client.readVirtualMainVolume(deviceID: deviceID) {
            return VolumeControl(
                kind: .virtualMain,
                volume: Self.clamp(volume),
                settable: client.isVirtualMainVolumeSettable(deviceID: deviceID)
            )
        }
        let readableChannels = [UInt32(1), UInt32(2)].compactMap { channel -> (UInt32, Float)? in
            guard let volume = client.readChannelVolume(deviceID: deviceID, channel: channel) else {
                return nil
            }
            return (channel, Self.clamp(volume))
        }
        guard !readableChannels.isEmpty else { return nil }
        let average = readableChannels.map(\.1).reduce(Float(0), +) / Float(readableChannels.count)
        let channels = readableChannels.map(\.0)
        let settable = channels.allSatisfy { client.isChannelVolumeSettable(deviceID: deviceID, channel: $0) }
        return VolumeControl(kind: .channels(channels), volume: average, settable: settable)
    }

    private static func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}

private struct VolumeControl {
    let kind: VolumeControlKind
    let volume: Float
    let settable: Bool
}

private enum VolumeControlKind {
    case virtualMain
    case channels([UInt32])
}
