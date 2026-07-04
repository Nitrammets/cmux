import Testing

@testable import CmuxMacPower

@Suite("MacAudioController")
struct MacAudioControllerTests {
    @Test func statusReadsVirtualMainVolumeAndMute() {
        let client = FakeMacAudioDeviceClient(virtualMainVolume: 0.3125, muted: true)
        let status = MacAudioController(client: client).status()

        #expect(status == MacAudioStatus(supported: true, volume: 0.3125, muted: true, volumeSettable: true))
    }

    @Test func setVolumeClampsBelowZeroBeforeWritingVirtualMainVolume() {
        let recorder = FakeMacAudioDeviceRecorder()
        let client = FakeMacAudioDeviceClient(virtualMainVolume: 0.5, recorder: recorder)

        _ = MacAudioController(client: client).setVolume(-0.25)

        #expect(recorder.writes == [.virtualMain(0)])
    }

    @Test func setVolumeClampsAboveOneBeforeWritingVirtualMainVolume() {
        let recorder = FakeMacAudioDeviceRecorder()
        let client = FakeMacAudioDeviceClient(virtualMainVolume: 0.5, recorder: recorder)

        _ = MacAudioController(client: client).setVolume(1.4)

        #expect(recorder.writes == [.virtualMain(1)])
    }

    @Test func setMutedWritesMuteAndReturnsFreshStatus() {
        let recorder = FakeMacAudioDeviceRecorder()
        let client = FakeMacAudioDeviceClient(virtualMainVolume: 0.25, muted: true, recorder: recorder)

        let status = MacAudioController(client: client).setMuted(false)

        #expect(recorder.writes == [.mute(false)])
        #expect(status == MacAudioStatus(supported: true, volume: 0.25, muted: true, volumeSettable: true))
    }

    @Test func channelVolumesAreFallbackWhenVirtualMainVolumeIsAbsent() {
        let recorder = FakeMacAudioDeviceRecorder()
        let client = FakeMacAudioDeviceClient(
            virtualMainVolume: nil,
            channelVolumes: [1: 0.2, 2: 0.6],
            recorder: recorder
        )

        let status = MacAudioController(client: client).setVolume(0.75)

        #expect(status == MacAudioStatus(supported: true, volume: 0.4, muted: false, volumeSettable: true))
        #expect(recorder.writes == [.channel(1, 0.75), .channel(2, 0.75)])
    }

    @Test func unsupportedDeviceReportsUnsupportedStatus() {
        let client = FakeMacAudioDeviceClient(defaultDeviceID: nil)

        let status = MacAudioController(client: client).status()

        #expect(status == MacAudioStatus(supported: false, volume: 0, muted: false, volumeSettable: false))
    }

    @Test func deviceWithoutVolumeControlsReportsUnsupportedStatus() {
        let client = FakeMacAudioDeviceClient(virtualMainVolume: nil, channelVolumes: [:])

        let status = MacAudioController(client: client).setVolume(0.5)

        #expect(status == MacAudioStatus(supported: false, volume: 0, muted: false, volumeSettable: false))
    }
}
