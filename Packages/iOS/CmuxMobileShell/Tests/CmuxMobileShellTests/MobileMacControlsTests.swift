import Foundation
import Testing

@testable import CmuxMobileShell

@Suite struct MobileMacControlsTests {
    @Test func audioStatusDecodesPayloadWithExtraKeys() throws {
        let data = Data("""
        {
          "supported": true,
          "volume": 0.625,
          "muted": true,
          "volume_settable": false,
          "ignored": "ok"
        }
        """.utf8)

        let status = try JSONDecoder().decode(MobileMacAudioStatus.self, from: data)

        #expect(status == MobileMacAudioStatus(supported: true, volume: 0.625, muted: true, volumeSettable: false))
    }

    @Test func audioStatusDefaultsMissingKeys() throws {
        let status = try JSONDecoder().decode(MobileMacAudioStatus.self, from: Data("{}".utf8))

        #expect(status == MobileMacAudioStatus(supported: false, volume: 0, muted: false, volumeSettable: false))
    }

    @Test func keyboardBacklightStatusDecodesPayloadWithExtraKeys() throws {
        let data = Data("""
        {
          "supported": true,
          "brightness": 0.25,
          "ignored": true
        }
        """.utf8)

        let status = try JSONDecoder().decode(MobileMacKeyboardBacklightStatus.self, from: data)

        #expect(status == MobileMacKeyboardBacklightStatus(supported: true, brightness: 0.25))
    }

    @Test func keyboardBacklightStatusDefaultsMissingKeys() throws {
        let status = try JSONDecoder().decode(MobileMacKeyboardBacklightStatus.self, from: Data("{}".utf8))

        #expect(status == MobileMacKeyboardBacklightStatus(supported: false, brightness: 0))
    }

    @MainActor
    @Test func capabilityGatesReflectHostCapabilities() {
        let store = MobileShellComposite(supportedHostCapabilities: [
            "mac.power.display_sleep.v1",
            "mac.audio.control.v1",
            "mac.keyboard_backlight.control.v1",
        ])

        #expect(store.supportsMacDisplaySleep)
        #expect(store.supportsMacAudioControl)
        #expect(store.supportsMacKeyboardBacklight)
        #expect(!store.supportsMacPowerControl)
    }

    @MainActor
    @Test func capabilityGatesDefaultToFalse() {
        let store = MobileShellComposite()

        #expect(!store.supportsMacDisplaySleep)
        #expect(!store.supportsMacAudioControl)
        #expect(!store.supportsMacKeyboardBacklight)
    }
}
