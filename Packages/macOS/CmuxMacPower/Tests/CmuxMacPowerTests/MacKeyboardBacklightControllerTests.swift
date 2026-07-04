import Testing

@testable import CmuxMacPower

@Suite("MacKeyboardBacklightController")
struct MacKeyboardBacklightControllerTests {
    @Test func statusIsUnsupportedWhenNoKeyboardIDsExist() {
        let status = MacKeyboardBacklightController(client: FakeMacKeyboardBacklightClient()).status()

        #expect(status == MacKeyboardBacklightStatus(supported: false, brightness: 0))
    }

    @Test func setBrightnessClampsAndTargetsFirstKeyboardID() {
        let recorder = FakeMacKeyboardBacklightRecorder()
        let client = FakeMacKeyboardBacklightClient(
            ids: [111, 222],
            brightnessByID: [111: 0.4, 222: 0.9],
            recorder: recorder
        )

        let status = MacKeyboardBacklightController(client: client).setBrightness(1.5)

        #expect(recorder.writes == [.init(keyboardID: 111, brightness: 1)])
        #expect(status == MacKeyboardBacklightStatus(supported: true, brightness: 0.4))
    }

    @Test func setBrightnessClampsLowBeforeWriting() {
        let recorder = FakeMacKeyboardBacklightRecorder()
        let client = FakeMacKeyboardBacklightClient(
            ids: [111],
            brightnessByID: [111: 0.2],
            recorder: recorder
        )

        _ = MacKeyboardBacklightController(client: client).setBrightness(-0.5)

        #expect(recorder.writes == [.init(keyboardID: 111, brightness: 0)])
    }
}
