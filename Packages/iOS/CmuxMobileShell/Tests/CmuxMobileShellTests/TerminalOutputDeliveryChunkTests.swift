import CMUXMobileCore
import Foundation
import Testing
@testable import CmuxMobileShell

@Suite
@MainActor
struct TerminalOutputDeliveryChunkTests {
    @Test
    func terminalRenderGridStreamDeliversFullSnapshotsAsBoundedPayload() async throws {
        let store = MobileShellComposite.preview()
        let surfaceID = "terminal-chunked"
        let frame = try Self.largeFullFrame(surfaceID: surfaceID, scrollbackRows: 1_200)

        var iterator = store.terminalOutputStream(surfaceID: surfaceID).makeAsyncIterator()
        let delivered = store.deliverTerminalRenderGrid(frame, surfaceID: surfaceID)
        #expect(delivered)
        let chunk = try #require(await iterator.next())

        #expect(chunk.isFullReplacement)
        #expect(chunk.payload.count >= 3)
        #expect(chunk.joinedPayload == frame.vtPatchBytes())
        for payloadChunk in chunk.payload {
            #expect(payloadChunk.count <= MobileTerminalRenderGridReplay.defaultMaxChunkBytes)
        }
    }

    @Test
    func terminalOutputPayloadAcksOncePerLogicalChunk() async throws {
        let store = MobileShellComposite.preview()
        let surfaceID = "terminal-logical-ack"
        let frame = try Self.largeFullFrame(surfaceID: surfaceID, scrollbackRows: 1_200)

        var iterator = store.terminalOutputStream(surfaceID: surfaceID).makeAsyncIterator()
        store.deliverTerminalRenderGrid(frame, surfaceID: surfaceID)
        let chunk = try #require(await iterator.next())
        store.deliverTerminalBytes(Data("after".utf8), surfaceID: surfaceID)

        #expect(store.terminalOutputQueuesBySurfaceID[surfaceID]?.pendingCount == 1)
        store.terminalOutputDidProcess(surfaceID: surfaceID, streamToken: chunk.streamToken)

        let after = try #require(await iterator.next())
        #expect(after.utf8Payload == "after")
    }

    @Test
    func terminalOutputResetDropsScrollbackPrefetchState() async throws {
        let store = MobileShellComposite.preview()
        let surfaceID = "terminal-reset-prefetch"

        var iterator = store.terminalOutputStream(surfaceID: surfaceID).makeAsyncIterator()
        store.deliverTerminalBytes(Data("stalled".utf8), surfaceID: surfaceID)
        let stalled = try #require(await iterator.next())
        store.terminalScrollbackPrefetchStatesBySurfaceID[surfaceID] =
            TerminalScrollbackPrefetchState(windowRows: 2_400, refreshDistanceRows: 10)

        store.terminalOutputDidReset(surfaceID: surfaceID, streamToken: stalled.streamToken)

        #expect(store.terminalScrollbackPrefetchStatesBySurfaceID[surfaceID] == nil)
    }

    @Test
    func terminalReplayAckResetDropsScrollbackPrefetchState() async throws {
        let store = MobileShellComposite.preview()
        let surfaceID = "terminal-replay-ack-prefetch"

        var iterator = store.terminalOutputStream(surfaceID: surfaceID).makeAsyncIterator()
        store.deliverTerminalBytes(Data("stalled".utf8), surfaceID: surfaceID)
        let stalled = try #require(await iterator.next())
        _ = store.beginTerminalReplayBarrier(surfaceID: surfaceID)
        store.deliverTerminalBytes(
            Data("authoritative-replay".utf8),
            surfaceID: surfaceID,
            bypassReplayBarrier: true
        )
        let replay = try #require(await iterator.next())
        #expect(replay.streamToken != stalled.streamToken)
        store.terminalScrollbackPrefetchStatesBySurfaceID[surfaceID] =
            TerminalScrollbackPrefetchState(windowRows: 2_400, refreshDistanceRows: 10)

        store.terminalOutputDidReset(surfaceID: surfaceID, streamToken: replay.streamToken)

        #expect(store.terminalScrollbackPrefetchStatesBySurfaceID[surfaceID] == nil)
    }

    private static func largeFullFrame(
        surfaceID: String,
        scrollbackRows: Int
    ) throws -> MobileTerminalRenderGridFrame {
        try MobileTerminalRenderGridFrame(
            surfaceID: surfaceID,
            stateSeq: 1,
            columns: 140,
            rows: 4,
            cursor: .init(row: 3, column: 8),
            rowSpans: (0..<4).map { row in
                .init(row: row, column: 0, text: "viewport-\(row)")
            },
            scrollbackRows: scrollbackRows,
            scrollbackSpans: (0..<scrollbackRows).map { row in
                .init(
                    row: row,
                    column: 0,
                    text: String(format: "history-%04d %@", row, String(repeating: "x", count: 96))
                )
            }
        )
    }
}
