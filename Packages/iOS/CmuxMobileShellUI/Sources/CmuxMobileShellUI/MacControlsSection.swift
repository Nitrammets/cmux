#if os(iOS)
import CmuxMobileShell
import CmuxMobileSupport
import SwiftUI

struct MacControlsSection: View {
    @Bindable var store: CMUXMobileShellStore
    let macDeviceID: String

    @State private var audioStatus: MobileMacAudioStatus?
    @State private var keyboardBacklightStatus: MobileMacKeyboardBacklightStatus?
    @State private var volumeDraft: Double = 0
    @State private var keyboardBacklightDraft: Double = 0
    @State private var isDraggingVolume = false
    @State private var isDraggingKeyboardBacklight = false
    @State private var busyOperationCount = 0
    @State private var controlsMessage: String?

    var body: some View {
        Section {
            if store.supportsMacAudioControl {
                audioRows
            }
            if store.supportsMacKeyboardBacklight, keyboardBacklightStatus?.supported == true {
                keyboardBacklightRows
            }
            if let controlsMessage {
                Label {
                    Text(controlsMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text(L10n.string("mobile.computers.section.controls", defaultValue: "Mac Controls"))
        }
        .task(id: controlsLoadKey) { await loadStatus() }
    }

    @ViewBuilder
    private var audioRows: some View {
        if let audioStatus, audioStatus.supported {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        L10n.string("mobile.computers.controls.volume", defaultValue: "Volume"),
                        systemImage: audioStatus.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    Spacer()
                    Text(volumePercentText)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { volumeDraft },
                        set: { volumeDraft = $0 }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingVolume = editing
                        if !editing { commitVolume() }
                    }
                )
                .disabled(!audioStatus.volumeSettable || isBusy)
                .accessibilityIdentifier("MobileMacVolumeSlider")
            }

            Toggle(isOn: Binding(
                get: { audioStatus.muted },
                set: { commitMuted($0) }
            )) {
                Label(L10n.string("mobile.computers.controls.mute", defaultValue: "Mute"), systemImage: "speaker.slash")
            }
            .disabled(isBusy)
            .accessibilityIdentifier("MobileMacMuteToggle")
        } else {
            unavailableRow(L10n.string(
                "mobile.computers.controls.audioUnavailable",
                defaultValue: "Output volume is unavailable on this Mac."))
        }
    }

    @ViewBuilder
    private var keyboardBacklightRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    L10n.string("mobile.computers.controls.keyboardBacklight", defaultValue: "Keyboard Backlight"),
                    systemImage: "keyboard.badge.ellipsis")
                Spacer()
                Text(keyboardBacklightPercentText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { keyboardBacklightDraft },
                    set: { keyboardBacklightDraft = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    isDraggingKeyboardBacklight = editing
                    if !editing { commitKeyboardBacklight() }
                }
            )
            .disabled(isBusy)
            .accessibilityIdentifier("MobileMacKeyboardBacklightSlider")
        }
    }

    private var controlsLoadKey: String {
        "\(store.supportsMacAudioControl)-\(store.supportsMacKeyboardBacklight)"
    }

    private var isBusy: Bool {
        busyOperationCount > 0
    }

    private var volumePercentText: String {
        percentText(volumeDraft)
    }

    private var keyboardBacklightPercentText: String {
        percentText(keyboardBacklightDraft)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    @ViewBuilder
    private func unavailableRow(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }
    }

    @MainActor
    private func beginOperation() {
        busyOperationCount += 1
    }

    @MainActor
    private func endOperation() {
        busyOperationCount = max(0, busyOperationCount - 1)
    }

    @MainActor
    private func loadStatus() async {
        beginOperation()
        defer { endOperation() }
        controlsMessage = nil
        var didFail = false
        if store.supportsMacAudioControl {
            if let status = await store.macAudioStatus(macDeviceID: macDeviceID) {
                applyAudioStatus(status)
            } else {
                audioStatus = nil
                didFail = true
            }
        }
        if store.supportsMacKeyboardBacklight {
            if let status = await store.macKeyboardBacklightStatus(macDeviceID: macDeviceID) {
                applyKeyboardBacklightStatus(status)
            } else {
                keyboardBacklightStatus = nil
                didFail = true
            }
        }
        if didFail {
            controlsMessage = L10n.string(
                "mobile.computers.controls.statusUnavailable",
                defaultValue: "Couldn't read Mac controls status.")
        }
    }

    @MainActor
    private func commitVolume() {
        beginOperation()
        controlsMessage = nil
        let volume = Float(volumeDraft)
        Task { @MainActor in
            defer { endOperation() }
            guard let status = await store.setMacVolume(volume, macDeviceID: macDeviceID) else {
                controlsMessage = L10n.string(
                    "mobile.computers.controls.volumeFailed",
                    defaultValue: "Couldn't update Mac volume.")
                return
            }
            applyAudioStatus(status)
        }
    }

    @MainActor
    private func commitMuted(_ muted: Bool) {
        beginOperation()
        controlsMessage = nil
        Task { @MainActor in
            defer { endOperation() }
            guard let status = await store.setMacMuted(muted, macDeviceID: macDeviceID) else {
                controlsMessage = L10n.string(
                    "mobile.computers.controls.muteFailed",
                    defaultValue: "Couldn't update Mac mute.")
                return
            }
            applyAudioStatus(status)
        }
    }

    @MainActor
    private func commitKeyboardBacklight() {
        beginOperation()
        controlsMessage = nil
        let brightness = Float(keyboardBacklightDraft)
        Task { @MainActor in
            defer { endOperation() }
            guard let status = await store.setMacKeyboardBacklight(brightness, macDeviceID: macDeviceID) else {
                controlsMessage = L10n.string(
                    "mobile.computers.controls.keyboardBacklightFailed",
                    defaultValue: "Couldn't update keyboard backlight.")
                return
            }
            applyKeyboardBacklightStatus(status)
        }
    }

    @MainActor
    private func applyAudioStatus(_ status: MobileMacAudioStatus) {
        audioStatus = status
        if !isDraggingVolume {
            volumeDraft = Double(status.volume)
        }
    }

    @MainActor
    private func applyKeyboardBacklightStatus(_ status: MobileMacKeyboardBacklightStatus) {
        keyboardBacklightStatus = status
        if !isDraggingKeyboardBacklight {
            keyboardBacklightDraft = Double(status.brightness)
        }
    }
}
#endif
