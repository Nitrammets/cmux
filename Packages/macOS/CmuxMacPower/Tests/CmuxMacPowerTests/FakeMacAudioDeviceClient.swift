@testable import CmuxMacPower

struct FakeMacAudioDeviceClient: MacAudioDeviceClient {
    var defaultDeviceID: UInt32?
    var virtualMainVolume: Float?
    var virtualMainSettable = true
    var channelVolumes: [UInt32: Float] = [:]
    var channelSettable: [UInt32: Bool] = [:]
    var muted: Bool?
    var muteSettable = true

    private let recorder: FakeMacAudioDeviceRecorder

    init(
        defaultDeviceID: UInt32? = 10,
        virtualMainVolume: Float? = nil,
        virtualMainSettable: Bool = true,
        channelVolumes: [UInt32: Float] = [:],
        channelSettable: [UInt32: Bool] = [:],
        muted: Bool? = false,
        muteSettable: Bool = true,
        recorder: FakeMacAudioDeviceRecorder = FakeMacAudioDeviceRecorder()
    ) {
        self.defaultDeviceID = defaultDeviceID
        self.virtualMainVolume = virtualMainVolume
        self.virtualMainSettable = virtualMainSettable
        self.channelVolumes = channelVolumes
        self.channelSettable = channelSettable
        self.muted = muted
        self.muteSettable = muteSettable
        self.recorder = recorder
    }

    var writes: [FakeMacAudioDeviceWrite] { recorder.writes }

    func defaultOutputDeviceID() -> UInt32? {
        defaultDeviceID
    }

    func readVirtualMainVolume(deviceID: UInt32) -> Float? {
        virtualMainVolume
    }

    func isVirtualMainVolumeSettable(deviceID: UInt32) -> Bool {
        virtualMainSettable
    }

    func setVirtualMainVolume(_ volume: Float, deviceID: UInt32) -> Bool {
        recorder.record(.virtualMain(volume))
        return true
    }

    func readChannelVolume(deviceID: UInt32, channel: UInt32) -> Float? {
        channelVolumes[channel]
    }

    func isChannelVolumeSettable(deviceID: UInt32, channel: UInt32) -> Bool {
        channelSettable[channel] ?? true
    }

    func setChannelVolume(_ volume: Float, deviceID: UInt32, channel: UInt32) -> Bool {
        recorder.record(.channel(channel, volume))
        return true
    }

    func readMute(deviceID: UInt32) -> Bool? {
        muted
    }

    func isMuteSettable(deviceID: UInt32) -> Bool {
        muteSettable
    }

    func setMute(_ muted: Bool, deviceID: UInt32) -> Bool {
        recorder.record(.mute(muted))
        return true
    }
}

// Test fakes are used from one task at a time by Swift Testing cases.
final class FakeMacAudioDeviceRecorder: @unchecked Sendable {
    private(set) var writes: [FakeMacAudioDeviceWrite] = []

    func record(_ write: FakeMacAudioDeviceWrite) {
        writes.append(write)
    }
}

enum FakeMacAudioDeviceWrite: Equatable {
    case virtualMain(Float)
    case channel(UInt32, Float)
    case mute(Bool)
}
