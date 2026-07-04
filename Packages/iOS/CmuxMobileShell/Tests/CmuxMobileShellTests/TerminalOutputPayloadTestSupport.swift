import Foundation
import CmuxMobileShellModel
@testable import CmuxMobileShell

extension MobileTerminalOutputChunk {
    var joinedPayload: Data {
        payload.reduce(into: Data()) { joined, chunk in
            joined.append(chunk)
        }
    }

    var utf8Payload: String {
        String(decoding: joinedPayload, as: UTF8.self)
    }
}

extension TerminalOutputDelivery {
    var joinedPayload: Data {
        payload.reduce(into: Data()) { joined, chunk in
            joined.append(chunk)
        }
    }
}
