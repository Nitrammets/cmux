#if canImport(UIKit)
import GhosttyKit
import UIKit

extension GhosttySurfaceView {
    /// Apply the scroll to the phone's local Ghostty mirror immediately. On the
    /// primary screen this consumes the preloaded local scrollback window, so a
    /// drag/deceleration feels native while the Mac catches up. On alternate
    /// screens libghostty turns this into mouse-wheel bytes; the mirror is
    /// display-only and drops those bytes, so the authoritative Mac response
    /// remains the visible update for TUIs.
    func applyLocalScrollbackScroll(lines: Double, col: Int, row: Int) {
        guard lines != 0, let surface else { return }
        let displayScale = window?.windowScene?.screen.scale ?? traitCollection.displayScale
        let scale = max(Double(displayScale), 1)
        let size = ghostty_surface_size(surface)
        let cellWidthPt = max(Double(size.cell_width_px) / scale, 1)
        let cellHeightPt = max(Double(size.cell_height_px) / scale, 1)
        let posX = (Double(max(0, col)) + 0.5) * cellWidthPt
        let posY = (Double(max(0, row)) + 0.5) * cellHeightPt
        ghostty_surface_mouse_pos(surface, posX, posY, GHOSTTY_MODS_NONE)
        ghostty_surface_mouse_scroll(surface, 0, lines, 0)
        drawForWakeup()
    }

    /// Row-exact viewport scroll on the local mirror via ghostty's
    /// `scroll_page_lines` binding action. Unlike the wheel path above, this is
    /// not subject to the discrete `mouse-scroll-multiplier` (3x by default),
    /// so callers restoring a measured scrollbar offset get exactly that many
    /// rows. Negative `lines` scroll upwards, into history.
    func scrollLocalViewportRows(_ lines: Int) {
        guard lines != 0, let surface else { return }
        let action = "scroll_page_lines:\(lines)"
        outputQueue.async {
            action.withCString { pointer in
                _ = ghostty_surface_binding_action(surface, pointer, UInt(action.utf8.count))
            }
        }
        drawForWakeup()
    }

    /// Record the mirror's Ghostty scrollbar geometry (`total` rows of
    /// scrollback + screen, viewport `offset` from the top, viewport `len`),
    /// fed by the runtime's `GHOSTTY_ACTION_SCROLLBAR` callback. The snapshot
    /// is nil until the mirror first reports one, which only happens once
    /// there is scrollback to scroll, so nil means "at bottom". The monotonic
    /// update count lets a caller that just mutated the terminal distinguish a
    /// fresh snapshot from the stale pre-mutation one.
    @MainActor
    func recordScrollbarSnapshot(total: Int, offset: Int, len: Int) {
        lastScrollbarSnapshot = (total: total, offset: offset, len: len)
        scrollbarUpdateCount += 1
    }

    /// How many rows the local mirror's viewport currently sits above the
    /// scrollback bottom. 0 when pinned to the live bottom.
    var scrollbackOffsetFromBottom: Int {
        guard let snapshot = lastScrollbarSnapshot else { return 0 }
        return max(0, snapshot.total - snapshot.len - snapshot.offset)
    }

    /// Apply a full render-grid replacement while preserving local scroll.
    ///
    /// Each sub-chunk is bounded so the flat 2s apply deadline remains valid
    /// by construction; recovery now only fires for genuinely wedged pipelines.
    /// The reset leaves the rebuilt mirror pinned to the bottom, so when the
    /// viewport was scrolled into scrollback the same offset-from-bottom is
    /// re-applied after every sub-chunk succeeds.
    /// - Parameter chunks: Full-snapshot VT chunks to feed into the surface.
    /// - Returns: `true` when the bytes reached the current surface generation,
    ///   or `false` when the caller should reset its delivery queue and replay.
    @discardableResult
    public func processFullReplacementOutputAndWait(_ chunks: [Data]) async -> Bool {
        let offsetFromBottom = scrollbackOffsetFromBottom
        for chunk in chunks where !chunk.isEmpty {
            let applied = await processOutputAndWait(chunk)
            guard applied else { return false }
        }
        if offsetFromBottom > 0 {
            scrollLocalViewportRows(-offsetFromBottom)
        }
        return true
    }

    /// Apply one full-replacement blob while preserving local scroll.
    /// - Parameter data: Full-snapshot VT bytes to feed into the surface.
    /// - Returns: `true` when the bytes reached the current surface generation.
    @discardableResult
    public func processFullReplacementOutputAndWait(_ data: Data) async -> Bool {
        await processFullReplacementOutputAndWait([data])
    }
}
#endif
