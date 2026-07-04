/// A snapshot of the Mac's default output volume and mute state.
///
/// `supported` is false when the default output device has no usable main or
/// channel-volume control. `volumeSettable` lets callers render read-only
/// output devices without hiding the whole audio section.
public struct MacAudioStatus: Sendable, Equatable {
    /// Whether the default output device exposes a readable volume control.
    public let supported: Bool
    /// The output volume normalized to `0...1`.
    public let volume: Float
    /// Whether the default output device is muted.
    public let muted: Bool
    /// Whether the output volume can be changed.
    public let volumeSettable: Bool

    /// Creates an output audio status snapshot.
    public init(supported: Bool, volume: Float, muted: Bool, volumeSettable: Bool) {
        self.supported = supported
        self.volume = volume
        self.muted = muted
        self.volumeSettable = volumeSettable
    }

    /// JSON-serializable wire form for the mobile RPC audio methods.
    public var jsonObject: [String: Any] {
        [
            "supported": supported,
            "volume": volume,
            "muted": muted,
            "volume_settable": volumeSettable,
        ]
    }
}
