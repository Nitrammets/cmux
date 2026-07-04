/// The connected Mac's default output volume and mute state.
///
/// Mirrors the Mac's `mac.audio.status` and `mac.audio.set` result
/// (`CmuxMacPower.MacAudioStatus`).
public struct MobileMacAudioStatus: Decodable, Sendable, Equatable {
    /// Whether the Mac exposes a readable output volume control.
    public let supported: Bool

    /// The output volume normalized to `0...1`.
    public let volume: Float

    /// Whether the output is muted.
    public let muted: Bool

    /// Whether the output volume can be changed.
    public let volumeSettable: Bool

    private enum CodingKeys: String, CodingKey {
        case supported
        case volume
        case muted
        case volumeSettable = "volume_settable"
    }

    /// Decodes an audio status snapshot from the Mac audio-control wire payload.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        supported = (try container.decodeIfPresent(Bool.self, forKey: .supported)) ?? false
        volume = (try container.decodeIfPresent(Float.self, forKey: .volume)) ?? 0
        muted = (try container.decodeIfPresent(Bool.self, forKey: .muted)) ?? false
        volumeSettable = (try container.decodeIfPresent(Bool.self, forKey: .volumeSettable)) ?? false
    }

    /// Creates an audio status snapshot for tests and local UI state.
    public init(supported: Bool, volume: Float, muted: Bool, volumeSettable: Bool) {
        self.supported = supported
        self.volume = volume
        self.muted = muted
        self.volumeSettable = volumeSettable
    }
}
