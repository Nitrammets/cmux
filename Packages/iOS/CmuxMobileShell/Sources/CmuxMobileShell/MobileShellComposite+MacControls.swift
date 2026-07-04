internal import CmuxMobileRPC
internal import Foundation
internal import OSLog

nonisolated private let macControlsLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "dev.cmux.ios",
    category: "mobile-mac-controls"
)

// MARK: - Mac display, audio, and keyboard controls

extension MobileShellComposite {
    /// Put the connected Mac's displays to sleep.
    public func sleepMacDisplays(macDeviceID: String? = nil) async -> MobileMacSleepResult {
        guard let client = macControlClient(for: macDeviceID) else { return .failed }
        let request: Data
        do {
            request = try MobileCoreRPCClient.requestData(
                method: "mac.power.displays_sleep",
                params: ["client_id": clientID]
            )
        } catch {
            macControlsLog.error("mac.power.displays_sleep request build failed error=\(String(describing: error), privacy: .public)")
            return .failed
        }
        do {
            _ = try await client.sendRequest(request)
            return .requested
        } catch {
            if disconnectForAuthorizationFailureIfNeeded(error) { return .failed }
            let result = MobileMacSleepErrorClassifier().result(forSendError: error)
            if result == .failed {
                macControlsLog.error("mac.power.displays_sleep failed error=\(String(describing: error), privacy: .public)")
            }
            return result
        }
    }

    /// Read the connected Mac's output volume and mute state.
    public func macAudioStatus(macDeviceID: String? = nil) async -> MobileMacAudioStatus? {
        await sendMacControlStatus(method: "mac.audio.status", macDeviceID: macDeviceID, responseType: MobileMacAudioStatus.self)
    }

    /// Set the connected Mac's output volume, then return the fresh status.
    public func setMacVolume(_ volume: Float, macDeviceID: String? = nil) async -> MobileMacAudioStatus? {
        await sendMacControlStatus(
            method: "mac.audio.set",
            params: ["client_id": clientID, "volume": volume],
            macDeviceID: macDeviceID,
            responseType: MobileMacAudioStatus.self
        )
    }

    /// Set the connected Mac's output mute state, then return the fresh status.
    public func setMacMuted(_ muted: Bool, macDeviceID: String? = nil) async -> MobileMacAudioStatus? {
        await sendMacControlStatus(
            method: "mac.audio.set",
            params: ["client_id": clientID, "muted": muted],
            macDeviceID: macDeviceID,
            responseType: MobileMacAudioStatus.self
        )
    }

    /// Read the connected Mac's keyboard backlight brightness.
    public func macKeyboardBacklightStatus(macDeviceID: String? = nil) async -> MobileMacKeyboardBacklightStatus? {
        await sendMacControlStatus(
            method: "mac.keyboard_backlight.status",
            macDeviceID: macDeviceID,
            responseType: MobileMacKeyboardBacklightStatus.self
        )
    }

    /// Set the connected Mac's keyboard backlight brightness, then return the fresh status.
    public func setMacKeyboardBacklight(_ brightness: Float, macDeviceID: String? = nil) async -> MobileMacKeyboardBacklightStatus? {
        await sendMacControlStatus(
            method: "mac.keyboard_backlight.set",
            params: ["client_id": clientID, "brightness": brightness],
            macDeviceID: macDeviceID,
            responseType: MobileMacKeyboardBacklightStatus.self
        )
    }

    private func sendMacControlStatus<T: Decodable>(
        method: String,
        params: [String: Any]? = nil,
        macDeviceID: String?,
        responseType: T.Type
    ) async -> T? {
        guard let client = macControlClient(for: macDeviceID) else { return nil }
        do {
            let request = try MobileCoreRPCClient.requestData(
                method: method,
                params: params ?? ["client_id": clientID]
            )
            let data = try await client.sendRequest(request)
            return try? JSONDecoder().decode(responseType, from: data)
        } catch {
            _ = disconnectForAuthorizationFailureIfNeeded(error)
            macControlsLog.error("\(method, privacy: .public) failed error=\(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
