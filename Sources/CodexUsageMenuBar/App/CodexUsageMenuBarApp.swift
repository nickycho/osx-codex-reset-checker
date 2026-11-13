import SwiftUI

@main
struct CodexUsageMenuBarApp: App {
    @StateObject private var viewModel: UsageViewModel

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
                .accessibilityLabel(
                    "剩餘 \(viewModel.menuBarTitle)，距離重設 \(viewModel.menuBarResetTitle(at: Date()) )"
                )
        }
        .menuBarExtraStyle(.window)
    }
}
