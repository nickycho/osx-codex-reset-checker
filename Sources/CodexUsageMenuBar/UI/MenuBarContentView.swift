import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @AppStorage("app.language") private var selectedLanguageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage.selected(selectedLanguageRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    usageSection
                    Divider()
                    ResetCreditsSection(
                        section: viewModel.state.resetCredits,
                        language: language
                    )
                }
                .padding(.vertical, 6)
                .padding(.trailing, 16)
            }

            Divider()
            languageSetting
            Text(AppLocalizer.versionDescription(language: language))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(AppLocalizer.text("app.quit", language: language))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 440, height: 640, alignment: .topLeading)
        .environment(\.locale, language.locale)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalizer.text("app.title", language: language))
                    .font(.system(size: 18, weight: .bold))
                Text(AppLocalizer.text("status.menuBar", language: language, viewModel.menuBarTitle))
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
            .help(AppLocalizer.text("refresh.help", language: language))
            .accessibilityLabel(AppLocalizer.text("refresh.accessibility", language: language))
            .disabled(viewModel.state.isRefreshing)
        }
    }

    private var languageSetting: some View {
        HStack {
            Text(AppLocalizer.text("settings.language", language: language))
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Picker(
                AppLocalizer.text("settings.language", language: language),
                selection: $selectedLanguageRaw
            ) {
                ForEach(AppLanguage.allCases) { option in
                    Text(AppLocalizer.text(option.displayNameKey, language: language))
                        .tag(option.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(AppLocalizer.text("usage.title", language: language))
                .font(.system(size: 17, weight: .semibold))

            sourceStatus(
                error: viewModel.state.usage.errorMessage,
                lastSuccessAt: viewModel.state.usage.lastSuccessAt
            )

            if viewModel.state.isRefreshing && viewModel.state.usage.value == nil {
                ProgressView {
                    Text(AppLocalizer.text("usage.loading", language: language))
                }
                .controlSize(.small)
            }

            if let usage = viewModel.state.usage.value {
                UsageWindowRow(
                    title: primaryWindowTitle(usage.primaryWindow),
                    window: usage.primaryWindow,
                    updatedAt: viewModel.state.usage.lastSuccessAt,
                    language: language
                )
                UsageWindowRow(
                    title: AppLocalizer.text("window.weekly", language: language),
                    window: usage.secondaryWindow,
                    updatedAt: viewModel.state.usage.lastSuccessAt,
                    language: language
                )

                ForEach(usage.additionalRateLimits) { limit in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(limit.name)
                            .font(.system(size: 16, weight: .semibold))
                        if limit.primaryWindow != nil {
                            UsageWindowRow(
                                title: AppLocalizer.text("window.current", language: language),
                                window: limit.primaryWindow,
                                updatedAt: viewModel.state.usage.lastSuccessAt,
                                language: language
                            )
                        }
                        if limit.secondaryWindow != nil {
                            UsageWindowRow(
                                title: AppLocalizer.text("window.weeklyQuota", language: language),
                                window: limit.secondaryWindow,
                                updatedAt: viewModel.state.usage.lastSuccessAt,
                                language: language
                            )
                        }
                        if limit.primaryWindow == nil && limit.secondaryWindow == nil {
                            Text(AppLocalizer.text("window.unavailable", language: language))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.primary.opacity(0.82))
                        }
                    }
                    .padding(.top, 3)
                }
            } else if !viewModel.state.isRefreshing, viewModel.state.usage.errorMessage == nil {
                Text(AppLocalizer.text("usage.noData", language: language))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
    }

    @ViewBuilder
    private func sourceStatus(error: AppErrorMessage?, lastSuccessAt: Date?) -> some View {
        if let error {
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
            if let lastSuccessAt {
                Text(AppLocalizer.text(
                    "status.staleData",
                    language: language,
                    AppLocalizer.time(lastSuccessAt, language: language)
                ))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
        } else if let lastSuccessAt {
            Text(AppLocalizer.text(
                "status.lastUpdated",
                language: language,
                AppLocalizer.time(lastSuccessAt, language: language)
            ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.82))
        }
    }

    private func primaryWindowTitle(_ window: UsageWindow?) -> String {
        guard let duration = window?.limitWindowSeconds else {
            return AppLocalizer.text("window.primaryUnknown", language: language)
        }
        guard duration != 18_000 else {
            return AppLocalizer.text("window.fiveHours", language: language)
        }
        return AppLocalizer.text(
            "window.primaryDuration",
            language: language,
            durationString(duration)
        )
    }

    private func durationString(_ seconds: Double) -> String {
        let maximumDisplaySeconds = TimeInterval(10 * 365 * 24 * 60 * 60)
        guard seconds.isFinite, seconds >= 0, seconds <= maximumDisplaySeconds else {
            return AppLocalizer.text("duration.unavailable", language: language)
        }
        let totalMinutes = max(0, Int(seconds / 60))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return AppLocalizer.text("duration.daysHours", language: language, days, hours)
        }
        if hours > 0, minutes > 0 {
            return AppLocalizer.text("duration.hoursMinutes", language: language, hours, minutes)
        }
        if hours > 0 {
            return AppLocalizer.text("duration.hours", language: language, hours)
        }
        return AppLocalizer.text("duration.minutes", language: language, minutes)
    }
}
