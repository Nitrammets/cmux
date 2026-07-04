import Foundation
import Testing
@testable import CMUXMobileCore

@Suite
struct MobileTerminalRenderGridReplayChunkTests {
    @Test
    func fullSnapshotChunksJoinToOriginalBytesAndStayBounded() throws {
        let maxChunkBytes = 4_096
        let frame = try Self.largePrimaryFrame(scrollbackRows: 1_200)
        let replay = MobileTerminalRenderGridReplay(frame)
        let chunks = replay.patchByteChunks(maxChunkBytes: maxChunkBytes)

        #expect(chunks.count >= 3)
        #expect(Self.join(chunks) == replay.patchBytes())
        #expect(Self.join(frame.vtPatchByteChunks()) == frame.vtPatchBytes())
        for chunk in chunks {
            #expect(chunk.count <= maxChunkBytes)
        }
    }

    @Test
    func smallFullSnapshotProducesOneChunk() throws {
        let frame = try MobileTerminalRenderGridFrame.fromPlainRows(
            surfaceID: "terminal-small",
            stateSeq: 2,
            columns: 20,
            rows: 2,
            text: "hello\nworld"
        )

        let chunks = MobileTerminalRenderGridReplay(frame).patchByteChunks()

        #expect(chunks.count == 1)
        #expect(Self.join(chunks) == frame.vtPatchBytes())
    }

    @Test
    func deltaFrameProducesOneUnchangedChunk() throws {
        let frame = try MobileTerminalRenderGridFrame.fromPlainRows(
            surfaceID: "terminal-delta",
            stateSeq: 3,
            columns: 20,
            rows: 2,
            text: "changed\n",
            full: false,
            changedRows: [0]
        )

        let chunks = MobileTerminalRenderGridReplay(frame).patchByteChunks(maxChunkBytes: 8)

        #expect(chunks == [frame.vtPatchBytes()])
    }

    @Test
    func alternateSnapshotChunksJoinAcrossScreenTransition() throws {
        let frame = try Self.largeAlternateFrame(scrollbackRows: 40)
        let replay = MobileTerminalRenderGridReplay(frame)
        let chunks = replay.patchByteChunks(maxChunkBytes: 512)

        #expect(chunks.count >= 3)
        #expect(Self.join(chunks) == replay.patchBytes())
    }

    private static func largePrimaryFrame(scrollbackRows: Int) throws -> MobileTerminalRenderGridFrame {
        try MobileTerminalRenderGridFrame(
            surfaceID: "terminal-large-primary",
            stateSeq: 1,
            columns: 120,
            rows: 4,
            cursor: .init(row: 3, column: 8),
            rowSpans: Self.viewportSpans(offset: scrollbackRows),
            scrollbackRows: scrollbackRows,
            scrollbackSpans: Self.scrollbackSpans(count: scrollbackRows)
        )
    }

    private static func largeAlternateFrame(scrollbackRows: Int) throws -> MobileTerminalRenderGridFrame {
        try MobileTerminalRenderGridFrame(
            surfaceID: "terminal-large-alternate",
            stateSeq: 4,
            columns: 120,
            rows: 4,
            cursor: .init(row: 1, column: 4),
            rowSpans: Self.viewportSpans(offset: 0),
            activeScreen: .alternate,
            scrollbackRows: scrollbackRows,
            scrollbackSpans: Self.scrollbackSpans(count: scrollbackRows)
        )
    }

    private static func scrollbackSpans(count: Int) -> [MobileTerminalRenderGridFrame.RowSpan] {
        (0..<count).map { row in
            .init(
                row: row,
                column: 0,
                text: String(format: "history-%04d %@", row, String(repeating: "x", count: 80))
            )
        }
    }

    private static func viewportSpans(offset: Int) -> [MobileTerminalRenderGridFrame.RowSpan] {
        (0..<4).map { row in
            .init(row: row, column: 0, text: "viewport-\(offset + row)")
        }
    }

    private static func join(_ chunks: [Data]) -> Data {
        chunks.reduce(into: Data()) { joined, chunk in
            joined.append(chunk)
        }
    }
}
