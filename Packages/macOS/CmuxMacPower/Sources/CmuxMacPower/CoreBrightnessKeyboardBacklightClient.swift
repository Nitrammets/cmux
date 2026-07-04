import Darwin
import Foundation
import ObjectiveC.runtime

/// Runtime-loaded CoreBrightness implementation of ``MacKeyboardBacklightClient``.
///
/// This is the only file that touches the private CoreBrightness framework. All
/// entry points are guarded so unsupported Macs and future framework changes
/// report no keyboard ids instead of crashing.
public struct CoreBrightnessKeyboardBacklightClient: MacKeyboardBacklightClient {
    // KeyboardBrightnessClient is immutable from this wrapper's perspective; calls are synchronous Objective-C messages.
    private nonisolated(unsafe) let client: AnyObject?

    /// Creates a runtime-probed CoreBrightness keyboard backlight client.
    public init() {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY) != nil,
              let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            client = nil
            return
        }
        client = clientClass.init()
    }

    /// Returns keyboard ids that expose a backlight.
    public func backlightKeyboardIDs() -> [UInt64] {
        guard let client,
              let method = Self.method(named: "copyKeyboardBacklightIDs", on: client) else {
            return []
        }
        typealias CopyIDsIMP = @convention(c) (AnyObject, Selector) -> AnyObject?
        let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
        let function = unsafeBitCast(method_getImplementation(method), to: CopyIDsIMP.self)
        guard let ids = function(client, selector) as? [NSNumber] else { return [] }
        return ids.map { $0.uint64Value }
    }

    /// Reads one keyboard's brightness, normalized to `0...1`.
    public func brightness(forKeyboard keyboardID: UInt64) -> Float? {
        guard let client,
              let method = Self.method(named: "brightnessForKeyboard:", on: client) else {
            return nil
        }
        typealias BrightnessIMP = @convention(c) (AnyObject, Selector, UInt64) -> Float
        let selector = NSSelectorFromString("brightnessForKeyboard:")
        let function = unsafeBitCast(method_getImplementation(method), to: BrightnessIMP.self)
        return function(client, selector, keyboardID)
    }

    /// Sets one keyboard's brightness.
    @discardableResult
    public func setBrightness(_ brightness: Float, forKeyboard keyboardID: UInt64) -> Bool {
        guard let client,
              let method = Self.method(named: "setBrightness:forKeyboard:", on: client) else {
            return false
        }
        typealias SetBrightnessIMP = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        let selector = NSSelectorFromString("setBrightness:forKeyboard:")
        let function = unsafeBitCast(method_getImplementation(method), to: SetBrightnessIMP.self)
        return function(client, selector, brightness, keyboardID)
    }

    private static func method(named name: String, on client: AnyObject) -> Method? {
        let selector = NSSelectorFromString(name)
        guard client.responds(to: selector) else { return nil }
        return class_getInstanceMethod(object_getClass(client), selector)
    }
}
