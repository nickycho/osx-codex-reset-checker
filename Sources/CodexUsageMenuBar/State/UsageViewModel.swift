import Combine
import Foundation

struct UsageDataSection<Value: Equatable>: Equatable {
    var value: Value?
    var lastSuccessAt: Date?
    var errorMessage: AppErrorMessage?

    init(value: Value? = nil, lastSuccessAt: Date? = nil, errorMessage: AppErrorMessage? = nil) {
        self.value = value
        self.lastSuccessAt = lastSuccessAt
        self.errorMessage = errorMessage
    }
}

struct UsagePanelState: Equatable {
    var usage = UsageDataSection<UsageResponse>()
    var resetCredits = UsageDataSection<ResetCreditsResponse>()
    var isRefreshing = false
}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var state = UsagePanelState()

    private let authFileReader: CodexAuthFileReader
    private let apiClient: CodexUsageAPIClient
    private var refreshLoop: Task<Void, Never>?

    init(
        authFileReader: CodexAuthFileReader = CodexAuthFileReader(),
        apiClient: CodexUsageAPIClient = CodexUsageAPIClient()
    ) {
        self.authFileReader = authFileReader
        self.apiClient = apiClient
    }

    var menuBarTitle: String {
        guard let window = state.usage.value?.primaryWindow,
              window.limitWindowSeconds == 18_000,
              let usedPercent = window.usedPercent,
              usedPercent.isFinite else {
            return "--%"
        }

        let remaining = Int((min(100, max(0, 100 - usedPercent))).rounded())
        return "\(remaining)%"
    }

    func menuBarResetTitle(at now: Date) -> String {
        guard let window = state.usage.value?.primaryWindow,
              window.limitWindowSeconds == 18_000 else {
            return "--:--"
        }

        let resetDate: Date
        if let resetAt = window.resetAt {
            resetDate = resetAt
        } else if let resetAfterSeconds = window.resetAfterSeconds,
                  let lastSuccessAt = state.usage.lastSuccessAt {
            resetDate = lastSuccessAt.addingTimeInterval(resetAfterSeconds)
        } else {
            return "--:--"
        }

        let interval = resetDate.timeIntervalSince(now)
        guard interval.isFinite, abs(interval) <= 253_402_300_799 else {
            return "--:--"
        }

        let remainingMinutes = max(0, Int(interval.rounded(.towardZero))) / 60
        let hours = remainingMinutes / 60
        let minutes = remainingMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    func startAutoRefresh() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !state.isRefreshing else { return }
        state.isRefreshing = true
        defer { state.isRefreshing = false }

        let credentials: CodexCredentials
        do {
            credentials = try authFileReader.loadCredentials()
        } catch {
            let message = AppErrorMessage(error)
            state.usage.errorMessage = message
            state.resetCredits.errorMessage = message
            return
        }

        let client = apiClient
        async let usageResult = Self.capture {
            try await client.fetchUsage(credentials: credentials)
        }
        async let creditsResult = Self.capture {
            try await client.fetchResetCredits(credentials: credentials)
        }
        let (usage, credits) = await (usageResult, creditsResult)
        let now = Date()

        switch usage {
        case .success(let value):
            state.usage.value = value
            state.usage.lastSuccessAt = now
            state.usage.errorMessage = nil
        case .failure(let failure):
            state.usage.errorMessage = failure.message
        }

        switch credits {
        case .success(let value):
            state.resetCredits.value = value
            state.resetCredits.lastSuccessAt = now
            state.resetCredits.errorMessage = nil
        case .failure(let failure):
            state.resetCredits.errorMessage = failure.message
        }
    }

    private nonisolated static func capture<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async -> Result<Value, RefreshFailure> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(RefreshFailure(message: AppErrorMessage(error)))
        }
    }
}

private struct RefreshFailure: Error, Sendable {
    let message: AppErrorMessage
}
