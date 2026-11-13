import SwiftUI

struct ResetCreditsSection: View {
    let section: UsageDataSection<ResetCreditsResponse>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("手動重置額度")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(countDescription)
                    .font(.system(size: 16, weight: .semibold))
            }

            sourceStatus

            if let response = section.value {
                if let credits = response.credits {
                    if credits.isEmpty {
                        Text("目前沒有可用的手動重置額度明細。")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.82))
                    } else {
                        ForEach(Array(credits.enumerated()), id: \.offset) { index, credit in
                            ResetCreditRow(index: index + 1, credit: credit)
                        }
                    }
                } else {
                    Text("服務未提供可辨識的額度明細清單。")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.82))
                }
            } else if !section.errorMessage.isNilOrEmpty {
                Text("尚未取得手動重置額度資料。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
    }

    private var countDescription: String {
        guard let count = section.value?.availableCount else { return "可用筆數未知" }
        return "可用 \(count) 筆"
    }

    @ViewBuilder
    private var sourceStatus: some View {
        if let error = section.errorMessage {
            Label("更新失敗：\(error)", systemImage: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            if let lastSuccessAt = section.lastSuccessAt {
                Text("沿用上次成功資料（\(timeString(lastSuccessAt))）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        } else if let lastSuccessAt = section.lastSuccessAt {
            Text("最後更新：\(timeString(lastSuccessAt))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
        }
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct ResetCreditRow: View {
    let index: Int
    let credit: ResetCredit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("額度 \(index)")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(credit.status ?? "狀態未提供")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
            Text("取得：\(dateString(credit.grantedAt))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
            Text("到期：\(dateString(credit.expiresAt))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text("剩餘時間：\(remainingTime(at: context.date))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func dateString(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .shortened) ?? "未提供"
    }

    private func remainingTime(at now: Date) -> String {
        guard let expiresAt = credit.expiresAt else { return "未提供" }

        let interval = expiresAt.timeIntervalSince(now)
        guard interval.isFinite, abs(interval) <= 253_402_300_799 else {
            return "不可用"
        }
        guard interval > 0 else { return "已到期" }

        let totalMinutes = max(1, Int(interval / 60))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        return "\(days)d \(hours)h \(minutes)m"
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
