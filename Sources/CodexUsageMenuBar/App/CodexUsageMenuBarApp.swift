import SwiftUI

@main
struct CodexUsageMenuBarApp: App {
    @StateObject private var viewModel: UsageViewModel
    @AppStorage("app.language") private var selectedLanguageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage.selected(selectedLanguageRaw)
    }

    init() {
        let model = UsageViewModel()
        _viewModel = StateObject(wrappedValue: model)
        model.startAutoRefresh()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            Text("\(viewModel.menuBarTitle) \(viewModel.menuBarResetTitle(at: Date()))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .accessibilityLabel(AppLocalizer.text(
                    "menubar.accessibility",
                    language: language,
                    viewModel.menuBarTitle,
                    viewModel.menuBarResetTitle(at: Date())
                ))
        }
        .menuBarExtraStyle(.window)
    }
}
