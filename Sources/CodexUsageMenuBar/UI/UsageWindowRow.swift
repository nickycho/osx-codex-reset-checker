import SwiftUI

struct UsageWindowRow: View {
    let title: String
    let window: UsageWindow?
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if let remaining = window?.remainingPercent {
                    Text("剩餘 \(Int(remaining.rounded()))%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                } else {
                    Text("比例不可用")
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
                    Text("已使用 \(Int(used.rounded()))%")
                } else {
                    Text("已使用資料不可用")
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
        guard let resetDate else { return "重設時間未提供" }
        let interval = resetDate.timeIntervalSince(now)
        guard interval.isFinite, abs(interval) <= 253_402_300_799 else {
            return "重設時間不可用"
        }
        let seconds = Int(interval.rounded(.towardZero))
        guard seconds > 0 else { return "重設時間已過，等待刷新" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "重設倒數 \(days)d \(hours)h" }
        if hours > 0 { return "重設倒數 \(hours)h \(minutes)m" }
        return "重設倒數 \(max(1, minutes))m"
    }
}
