@testable import CmuxMacPower

struct FakeMacKeyboardBacklightClient: MacKeyboardBacklightClient {
    var ids: [UInt64]
    var brightnessByID: [UInt64: Float]
    private let recorder: FakeMacKeyboardBacklightRecorder

    init(
        ids: [UInt64] = [],
        brightnessByID: [UInt64: Float] = [:],
        recorder: FakeMacKeyboardBacklightRecorder = FakeMacKeyboardBacklightRecorder()
    ) {
        self.ids = ids
        self.brightnessByID = brightnessByID
        self.recorder = recorder
    }

    func backlightKeyboardIDs() -> [UInt64] {
        ids
    }

    func brightness(forKeyboard keyboardID: UInt64) -> Float? {
        brightnessByID[keyboardID]
    }

    func setBrightness(_ brightness: Float, forKeyboard keyboardID: UInt64) -> Bool {
        recorder.record(.init(keyboardID: keyboardID, brightness: brightness))
        return true
    }
}

// Test fakes are used from one task at a time by Swift Testing cases.
final class FakeMacKeyboardBacklightRecorder: @unchecked Sendable {
    private(set) var writes: [FakeMacKeyboardBacklightWrite] = []

    func record(_ write: FakeMacKeyboardBacklightWrite) {
        writes.append(write)
    }
}

struct FakeMacKeyboardBacklightWrite: Equatable {
    let keyboardID: UInt64
    let brightness: Float
}
