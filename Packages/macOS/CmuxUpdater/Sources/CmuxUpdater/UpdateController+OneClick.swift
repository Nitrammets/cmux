import Foundation
@preconcurrency import Sparkle

struct UpdateOneClickProviders {
    let whatsNewProvider: UpdateWhatsNewProvider
    let latestVersionProvider: UpdateLatestAppcastVersionProvider
}

struct UpdateWhatsNewLoadState {
    var task: Task<Void, Never>?
    var requestedVersion: String?
}

struct UpdateStagedFreshnessState {
    var task: Task<Void, Never>?
    var checkedStagedVersion: String?
    var staleVersionToSkip: String?
    var targetVersion: String?
    var pendingBackgroundCheck = false
    var backgroundCheckTask: Task<Void, Never>?
}

/// The one-click auto-update flows layered on ``UpdateController``: kicking the silent
/// background download when a probe detects an update, retrying transient background
/// failures, and the deferred "restart when idle" loop.
///
/// Split from `UpdateController.swift` to keep that file within the repo's Swift file-length
/// budget; state lives on the class (see the "One-click auto-update state" properties there).
extension UpdateController {
    // MARK: - Silent background download

    /// Starts Sparkle's background session (which downloads and stages the update silently when
    /// automatic downloads are enabled) once the session that detected the update has finished.
    ///
    /// Without this, the payload isn't fetched until Sparkle's next scheduled check, so the
    /// user who clicks "install" pays the download (and any transient CDN failure, #5632) at
    /// click time. Keyed on Sparkle's `didFinishUpdateCycle` signal (not a timer); the same
    /// 100ms teardown beat as the re-check path lets Sparkle finish tearing the session down
    /// before a new one starts, and the `canCheckForUpdates`/idle guards keep it from
    /// interrupting a user-initiated flow.
    func startSilentDownloadIfKickPending() {
        guard pendingSilentDownloadKick else { return }
        guard !isDevLikeBundle else {
            pendingSilentDownloadKick = false
            return
        }
        guard updater.automaticallyDownloadsUpdates else {
            pendingSilentDownloadKick = false
            return
        }
        silentDownloadKickTask?.cancel()
        silentDownloadKickTask = Task { @MainActor [weak self] in
            defer { self?.silentDownloadKickTask = nil }
            guard let self else { return }
            try? await self.clock.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            guard self.model.state.isIdle, self.model.overrideState == nil else { return }
            guard self.updater.canCheckForUpdates else { return }
            let version = self.model.detectedUpdateVersion
            if version != self.silentDownloadKickedVersion {
                self.backgroundRetryCount = 0
            }
            self.pendingSilentDownloadKick = false
            self.silentDownloadKickedVersion = version
            self.log.append("starting silent background download of detected update")
            self.updater.checkForUpdatesInBackground()
        }
    }

    // MARK: - Toast changelog bullets

    func refreshWhatsNewForStagedVersionIfNeeded() {
        guard let version = model.updateReadyToastInstalling?.stagedVersion, !version.isEmpty else {
            whatsNewState.task?.cancel()
            whatsNewState.task = nil
            whatsNewState.requestedVersion = nil
            model.setUpdateReadyWhatsNew(version: nil, bullets: [])
            return
        }
        guard whatsNewState.requestedVersion != version else { return }
        whatsNewState.requestedVersion = version
        model.setUpdateReadyWhatsNew(version: version, bullets: [])
        whatsNewState.task?.cancel()
        whatsNewState.task = Task { @MainActor [weak self] in
            guard let self else { return }
            let bullets = await self.oneClickProviders.whatsNewProvider.bullets(for: version)
            guard !Task.isCancelled else { return }
            guard self.model.updateReadyToastInstalling?.stagedVersion == version else { return }
            self.model.setUpdateReadyWhatsNew(version: version, bullets: bullets)
        }
    }

    // MARK: - Staged-version freshness

    func scheduleStagedFreshnessCheckIfNeeded() {
        guard case .installing(let installing) = model.state,
              installing.isAutoUpdate,
              let stagedVersion = installing.stagedVersion,
              !stagedVersion.isEmpty,
              updater.automaticallyDownloadsUpdates,
              !isDevLikeBundle else {
            stagedFreshnessState.task?.cancel()
            stagedFreshnessState.task = nil
            stagedFreshnessState.checkedStagedVersion = nil
            return
        }
        guard stagedFreshnessState.checkedStagedVersion != stagedVersion else { return }
        stagedFreshnessState.checkedStagedVersion = stagedVersion
        stagedFreshnessState.task?.cancel()
        stagedFreshnessState.task = Task { @MainActor [weak self] in
            guard let self else { return }
            let feedURLString = self.feedURLStringForFreshnessCheck()
            guard let latestVersion = await self.oneClickProviders.latestVersionProvider.latestVersion(feedURLString: feedURLString),
                  UpdateVersionComparator.isNewer(latestVersion, than: stagedVersion) else { return }
            guard !Task.isCancelled else { return }
            self.prepareStagedFreshnessRestage(staleVersion: stagedVersion, latestVersion: latestVersion)
        }
    }

    func prepareStagedFreshnessRestage(staleVersion: String, latestVersion: String, startResumeCheck: Bool = true) {
        guard case .installing(let installing) = model.state,
              installing.isAutoUpdate,
              installing.stagedVersion == staleVersion else {
            return
        }
        stagedFreshnessState.staleVersionToSkip = staleVersion
        stagedFreshnessState.targetVersion = latestVersion
        log.append("newer update available while staged (staged=\(staleVersion), latest=\(latestVersion)); refreshing staged install")
        guard startResumeCheck else { return }
        startUpdaterIfNeeded()
        guard updater.canCheckForUpdates else { return }
        updater.checkForUpdatesInBackground()
    }

    func shouldSkipStaleStagedUpdate(displayVersion: String, stage: SPUUserUpdateStage) -> Bool {
        guard let staleVersion = stagedFreshnessState.staleVersionToSkip,
              UpdateStateModel.normalizedDetectedUpdateVersion(from: displayVersion) == staleVersion else {
            return false
        }
        guard stage == .downloaded || stage == .installing else { return false }
        stagedFreshnessState.staleVersionToSkip = nil
        stagedFreshnessState.pendingBackgroundCheck = true
        log.append("stale staged update skipped; will fetch latest \(stagedFreshnessState.targetVersion ?? "<unknown>")")
        return true
    }

    func startStagedFreshnessBackgroundCheckIfPending() {
        guard stagedFreshnessState.pendingBackgroundCheck else { return }
        guard !isDevLikeBundle else {
            stagedFreshnessState.pendingBackgroundCheck = false
            return
        }
        stagedFreshnessState.backgroundCheckTask?.cancel()
        stagedFreshnessState.backgroundCheckTask = Task { @MainActor [weak self] in
            defer { self?.stagedFreshnessState.backgroundCheckTask = nil }
            guard let self else { return }
            try? await self.clock.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            guard self.updater.automaticallyDownloadsUpdates, self.updater.canCheckForUpdates else { return }
            self.stagedFreshnessState.pendingBackgroundCheck = false
            self.log.append("starting background check to stage newer update")
            self.updater.checkForUpdatesInBackground()
        }
    }

    private func feedURLStringForFreshnessCheck() -> String {
        if let last = driver.resolvedFeedURLString(), !last.isEmpty {
            return last
        }
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["CMUX_UI_TEST_FEED_URL"], !override.isEmpty {
            return override
        }
        #endif
        let infoFeedURL = hostBundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        return UpdateFeedResolver().resolve(infoFeedURL: infoFeedURL).url
    }

    /// Schedules a bounded silent retry after a transient background failure (GitHub's release
    /// CDN intermittently 504s individual objects; Sparkle itself never retries, #5632).
    /// Non-transient failures and exhausted retries fall back to the next scheduled check.
    func scheduleBackgroundRetryIfTransient(_ error: any Error) {
        guard isTransientUpdateNetworkError(error) else { return }
        guard backgroundRetryCount < backgroundRetryLimit else {
            log.append("background update retry limit reached; waiting for next scheduled check")
            return
        }
        backgroundRetryCount += 1
        log.append("scheduling background update retry \(backgroundRetryCount)/\(backgroundRetryLimit)")
        backgroundRetryTask?.cancel()
        backgroundRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: self.backgroundRetryDelay)
            guard !Task.isCancelled else { return }
            guard self.model.state.isIdle, self.updater.canCheckForUpdates else { return }
            self.log.append("retrying silent background update download")
            self.updater.checkForUpdatesInBackground()
        }
    }

    // MARK: - Restart when idle

    /// Defers the staged update's restart until the host reports the user is idle
    /// (``UpdateActionDelegate/updaterIsSafeToRestartNow()``), then completes the install.
    ///
    /// The poll is a genuine periodic schedule on the injected clock, cancelled when the user
    /// restarts manually or the staged install goes away (see `handleStateChange`).
    public func requestRestartWhenIdle() {
        guard case .installing = model.effectiveState else {
            log.append("restart-when-idle ignored (no staged install)")
            return
        }
        model.setRestartWhenIdleArmed(true)
        log.append("restart-when-idle armed")
        guard case .installing = model.state else {
            // Debug override without a real staged install: arm the UI state only.
            return
        }
        restartWhenIdleTask?.cancel()
        restartWhenIdleTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await self.clock.sleep(for: self.restartWhenIdlePollInterval)
                guard !Task.isCancelled else { return }
                guard self.model.isRestartWhenIdleArmed,
                      case .installing(let installing) = self.model.state else {
                    self.cancelRestartWhenIdleLoop()
                    return
                }
                guard self.actionDelegate?.updaterIsSafeToRestartNow() == true else { continue }
                self.log.append("restart-when-idle firing (host reports idle)")
                installing.retryTerminatingApplication()
            }
        }
    }

    func cancelRestartWhenIdleLoop() {
        restartWhenIdleTask?.cancel()
        restartWhenIdleTask = nil
    }

    // MARK: - Toast mute expiry

    func scheduleToastMuteExpiryIfNeeded() {
        toastMuteExpiryTask?.cancel()
        toastMuteExpiryTask = nil

        guard let mutedUntil = model.updateReadyToastMutedUntil else { return }
        let delay = max(0, mutedUntil.timeIntervalSince(model.now()))
        toastMuteExpiryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.model.expireUpdateReadyToastMuteIfNeeded()
            self.toastMuteExpiryTask = nil
        }
    }
}

enum UpdateVersionComparator {
    static func isNewer(_ candidate: String, than staged: String) -> Bool {
        compare(candidate, staged) == .orderedDescending
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        guard !left.isEmpty, !right.isEmpty else { return .orderedSame }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l > r { return .orderedDescending }
            if l < r { return .orderedAscending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropPrefix("v")
            .split(separator: ".", maxSplits: 2)
            .compactMap { Int($0.prefix(while: \.isNumber)) }
    }
}

private extension StringProtocol {
    func dropPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : String(self)
    }
}
