import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    usageSection
                    Divider()
                    ResetCreditsSection(section: viewModel.state.resetCredits)
                }
                .padding(.vertical, 6)
                .padding(.trailing, 16)
            }

            Divider()
            Button("結束 Codex 額度") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 440, height: 640, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex 額度")
                    .font(.system(size: 18, weight: .bold))
                Text("狀態列：\(viewModel.menuBarTitle)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.state.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.borderless)
            .help("立即刷新")
            .accessibilityLabel("立即刷新額度")
            .disabled(viewModel.state.isRefreshing)
        }
    }

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("使用額度")
                .font(.system(size: 17, weight: .semibold))

            sourceStatus(
                error: viewModel.state.usage.errorMessage,
                lastSuccessAt: viewModel.state.usage.lastSuccessAt
            )

            if viewModel.state.isRefreshing && viewModel.state.usage.value == nil {
                ProgressView("正在查詢…")
                    .controlSize(.small)
            }

            if let usage = viewModel.state.usage.value {
                UsageWindowRow(
                    title: primaryWindowTitle(usage.primaryWindow),
                    window: usage.primaryWindow,
                    updatedAt: viewModel.state.usage.lastSuccessAt
                )
                UsageWindowRow(
                    title: "每週視窗",
                    window: usage.secondaryWindow,
                    updatedAt: viewModel.state.usage.lastSuccessAt
                )

                ForEach(usage.additionalRateLimits) { limit in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(limit.name)
                            .font(.system(size: 16, weight: .semibold))
                        if limit.primaryWindow != nil {
                            UsageWindowRow(
                                title: "目前額度",
                                window: limit.primaryWindow,
                                updatedAt: viewModel.state.usage.lastSuccessAt
                            )
                        }
                        if limit.secondaryWindow != nil {
                            UsageWindowRow(
                                title: "每週額度",
                                window: limit.secondaryWindow,
                                updatedAt: viewModel.state.usage.lastSuccessAt
                            )
                        }
                        if limit.primaryWindow == nil && limit.secondaryWindow == nil {
                            Text("此模型的額度視窗資料不可用。")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.primary.opacity(0.82))
                        }
                    }
                    .padding(.top, 3)
                }
            } else if !viewModel.state.isRefreshing, viewModel.state.usage.errorMessage == nil {
                Text("目前沒有可用的使用額度資料。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
    }

    @ViewBuilder
    private func sourceStatus(error: String?, lastSuccessAt: Date?) -> some View {
        if let error {
            Label("更新失敗：\(error)", systemImage: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            if let lastSuccessAt {
                Text("沿用上次成功資料（\(timeString(lastSuccessAt))）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        } else if let lastSuccessAt {
            Text("最後更新：\(timeString(lastSuccessAt))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
        }
    }

    private func primaryWindowTitle(_ window: UsageWindow?) -> String {
        guard let duration = window?.limitWindowSeconds else {
            return "主要視窗（時長未知）"
        }
        guard duration != 18_000 else { return "5 小時視窗" }
        return "主要視窗（\(durationString(duration))）"
    }

    private func durationString(_ seconds: Double) -> String {
        let maximumDisplaySeconds = TimeInterval(10 * 365 * 24 * 60 * 60)
        guard seconds.isFinite, seconds >= 0, seconds <= maximumDisplaySeconds else {
            return "時長不可用"
        }
        let totalMinutes = max(0, Int(seconds / 60))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "\(days) 天 \(hours) 小時" }
        if hours > 0, minutes > 0 { return "\(hours) 小時 \(minutes) 分" }
        if hours > 0 { return "\(hours) 小時" }
        return "\(minutes) 分鐘"
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
