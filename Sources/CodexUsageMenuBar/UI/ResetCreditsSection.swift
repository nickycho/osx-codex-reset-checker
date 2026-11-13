import SwiftUI

struct ResetCreditsSection: View {
    let section: UsageDataSection<ResetCreditsResponse>
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppLocalizer.text("credits.title", language: language))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(countDescription)
                    .font(.system(size: 16, weight: .semibold))
            }

            sourceStatus

            if let response = section.value {
                if let credits = response.credits {
                    if credits.isEmpty {
                        Text(AppLocalizer.text("credits.empty", language: language))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.82))
                    } else {
                        ForEach(Array(credits.enumerated()), id: \.offset) { index, credit in
                            ResetCreditRow(
                                index: index + 1,
                                credit: credit,
                                language: language
                            )
                        }
                    }
                } else {
                    Text(AppLocalizer.text("credits.listUnavailable", language: language))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.82))
                }
            } else if section.errorMessage == nil {
                Text(AppLocalizer.text("credits.notLoaded", language: language))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
    }

    private var countDescription: String {
        guard let count = section.value?.availableCount else {
            return AppLocalizer.text("credits.countUnknown", language: language)
        }
        return AppLocalizer.text("credits.count", language: language, count)
    }

    @ViewBuilder
    private var sourceStatus: some View {
        if let error = section.errorMessage {
            Label {
                Text(AppLocalizer.text(
                    "status.updateFailed",
                    language: language,
                    error.localizedDescription(language: language)
                ))
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.orange)
            if let lastSuccessAt = section.lastSuccessAt {
                Text(AppLocalizer.text(
                    "status.staleData",
                    language: language,
                    AppLocalizer.time(lastSuccessAt, language: language)
                ))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        } else if let lastSuccessAt = section.lastSuccessAt {
            Text(AppLocalizer.text(
                "status.lastUpdated",
                language: language,
                AppLocalizer.time(lastSuccessAt, language: language)
            ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
        }
    }
}

private struct ResetCreditRow: View {
    let index: Int
    let credit: ResetCredit
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppLocalizer.text("credits.rowTitle", language: language, index))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
            Text(AppLocalizer.text(
                "credits.granted",
                language: language,
                AppLocalizer.dateTime(credit.grantedAt, language: language)
            ))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
            Text(AppLocalizer.text(
                "credits.expires",
                language: language,
                AppLocalizer.dateTime(credit.expiresAt, language: language)
            ))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(AppLocalizer.text(
                    "credits.remaining",
                    language: language,
                    remainingTime(at: context.date)
                ))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        guard let status = credit.status else {
            return AppLocalizer.text("credits.statusUnavailable", language: language)
        }
        switch status.lowercased() {
        case "available":
            return AppLocalizer.text("credits.statusAvailable", language: language)
        case "unavailable":
            return AppLocalizer.text("credits.statusUnavailable", language: language)
        case "expired":
            return AppLocalizer.text("credits.statusExpired", language: language)
        default:
            return status
        }
    }

    private func remainingTime(at now: Date) -> String {
        guard let expiresAt = credit.expiresAt else {
            return AppLocalizer.text("value.notProvided", language: language)
        }

        let interval = expiresAt.timeIntervalSince(now)
        guard interval.isFinite, abs(interval) <= 253_402_300_799 else {
            return AppLocalizer.text("value.unavailable", language: language)
        }
        guard interval > 0 else {
            return AppLocalizer.text("credits.expired", language: language)
        }

        let totalMinutes = max(1, Int(interval / 60))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        return AppLocalizer.text(
            "credits.countdown",
            language: language,
            days,
            hours,
            minutes
        )
    }
}
