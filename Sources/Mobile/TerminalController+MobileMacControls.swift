import CmuxMacPower
import Foundation

extension TerminalController {
    /// `mac.power.displays_sleep`: put only the Mac's displays to sleep now.
    /// Uses `pmset displaysleepnow`, so it does not require the System Events
    /// Automation grant used by whole-system sleep.
    func v2MacPowerSleepDisplays() async -> V2CallResult {
        let didSleepDisplays = await MacPowerController().sleepDisplays()
        guard didSleepDisplays else {
            return .err(
                code: "display_sleep_failed",
                message: String(
                    localized: "mobile.macPower.displaySleepFailed",
                    defaultValue: "macOS couldn't complete the display sleep request."
                ),
                data: nil
            )
        }
        return .ok(["ok": true])
    }

    /// `mac.audio.status`: report the default output volume and mute state.
    /// Unsupported devices return a successful `{ supported: false }` status so
    /// the phone can hide or disable controls without treating it as transport
    /// failure.
    func v2MacAudioStatus() -> V2CallResult {
        .ok(MacAudioController().status().jsonObject)
    }

    /// `mac.audio.set`: set output volume and/or mute, then return fresh status.
    ///
    /// Params: optional `{ volume: Number, muted: Bool }`. Volume is normalized
    /// `0...1` and clamped by ``MacAudioController``.
    func v2MacAudioSet(params: [String: Any]) -> V2CallResult {
        let hasVolume = v2HasNonNullParam(params, "volume")
        let hasMuted = v2HasNonNullParam(params, "muted")
        guard hasVolume || hasMuted else {
            return .err(
                code: "invalid_params",
                message: String(
                    localized: "mobile.macAudio.setMissingParams",
                    defaultValue: "mac.audio.set requires volume and/or muted"
                ),
                data: nil
            )
        }
        let controller = MacAudioController()
        var status: MacAudioStatus?
        if hasVolume {
            guard let volume = v2Double(params, "volume"), volume.isFinite else {
                return .err(
                    code: "invalid_params",
                    message: String(
                        localized: "mobile.macAudio.volumeInvalid",
                        defaultValue: "volume must be a finite number"
                    ),
                    data: nil
                )
            }
            status = controller.setVolume(Float(volume))
        }
        if hasMuted {
            guard let muted = v2Bool(params, "muted") else {
                return .err(
                    code: "invalid_params",
                    message: String(
                        localized: "mobile.macAudio.mutedInvalid",
                        defaultValue: "muted must be a boolean"
                    ),
                    data: nil
                )
            }
            status = controller.setMuted(muted)
        }
        return .ok((status ?? controller.status()).jsonObject)
    }

    /// `mac.keyboard_backlight.status`: report the keyboard backlight brightness.
    /// Unsupported Macs return a successful `{ supported: false }` status because
    /// the CoreBrightness private API is runtime-probed and intentionally absent
    /// on some machines.
    func v2MacKeyboardBacklightStatus() -> V2CallResult {
        .ok(MacKeyboardBacklightController().status().jsonObject)
    }

    /// `mac.keyboard_backlight.set`: set keyboard backlight brightness, then
    /// return fresh status.
    ///
    /// Params: `{ brightness: Number }`, normalized `0...1` and clamped by
    /// ``MacKeyboardBacklightController``.
    func v2MacKeyboardBacklightSet(params: [String: Any]) -> V2CallResult {
        guard let brightness = v2Double(params, "brightness"), brightness.isFinite else {
            return .err(
                code: "invalid_params",
                message: String(
                    localized: "mobile.macKeyboardBacklight.brightnessInvalid",
                    defaultValue: "brightness must be a finite number"
                ),
                data: nil
            )
        }
        return .ok(MacKeyboardBacklightController().setBrightness(Float(brightness)).jsonObject)
    }
}
