import SwiftUI

struct UsageWindowRow: View {
    let title: String
    let window: UsageWindow?
    let updatedAt: Date?
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if let remaining = window?.remainingPercent {
                    Text(AppLocalizer.text(
                        "usage.remaining",
                        language: language,
                        Int(remaining.rounded())
                    ))
                        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                } else {
                    Text(AppLocalizer.text("usage.ratioUnavailable", language: language))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.82))
                }
            }

            if let remaining = window?.remainingPercent {
                ProgressView(value: remaining, total: 100)
                    .tint(remaining <= 20 ? .orange : .accentColor)
            }

            HStack {
                if let used = window?.usedPercent {
                    Text(AppLocalizer.text(
                        "usage.used",
                        language: language,
                        Int(used.rounded())
                    ))
                } else {
                    Text(AppLocalizer.text("usage.usedUnavailable", language: language))
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(resetDescription(at: context.date))
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.82))
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var resetDate: Date? {
        if let resetAt = window?.resetAt { return resetAt }
        if let interval = window?.resetAfterSeconds, let updatedAt {
            return updatedAt.addingTimeInterval(interval)
        }
        return nil
    }

    private func resetDescription(at now: Date) -> String {
        guard let resetDate else {
            return AppLocalizer.text("reset.notProvided", language: language)
        }
        let interval = resetDate.timeIntervalSince(now)
        guard interval.isFinite, abs(interval) <= 253_402_300_799 else {
            return AppLocalizer.text("reset.unavailable", language: language)
        }
        let seconds = Int(interval.rounded(.towardZero))
        guard seconds > 0 else {
            return AppLocalizer.text("reset.passed", language: language)
        }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return AppLocalizer.text("reset.countdown.days", language: language, days, hours)
        }
        if hours > 0 {
            return AppLocalizer.text("reset.countdown.hours", language: language, hours, minutes)
        }
        return AppLocalizer.text(
            "reset.countdown.minutes",
            language: language,
            max(1, minutes)
        )
    }
}
