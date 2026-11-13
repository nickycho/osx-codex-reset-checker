import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var localizationCode: String {
        switch self {
        case .system:
            Self.systemLocalizationCode
        case .english:
            "en"
        case .chineseTraditional:
            "zh-Hant"
        case .japanese:
            "ja"
        case .korean:
            "ko"
        }
    }

    var locale: Locale {
        Locale(identifier: localizationCode)
    }

    var displayNameKey: String {
        switch self {
        case .system: "language.system"
        case .english: "language.english"
        case .chineseTraditional: "language.chineseTraditional"
        case .japanese: "language.japanese"
        case .korean: "language.korean"
        }
    }

    static var systemLocalizationCode: String {
        let preferredLanguage = Locale.preferredLanguages.first?
            .lowercased()
            .replacingOccurrences(of: "_", with: "-") ?? "en"
        if preferredLanguage.hasPrefix("zh") { return "zh-Hant" }
        if preferredLanguage.hasPrefix("ja") { return "ja" }
        if preferredLanguage.hasPrefix("ko") { return "ko" }
        if preferredLanguage.hasPrefix("en") { return "en" }
        return "en"
    }

    static func selected(_ rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }
}

enum AppLocalizer {
    static func text(
        _ key: String,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        let bundle = localizedBundle(for: language)
        let format = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    static func time(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date?, language: AppLanguage) -> String {
        guard let date else { return text("value.notProvided", language: language) }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func versionDescription(language: AppLanguage) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        return text("app.version", language: language, version)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.module.path(
            forResource: language.localizationCode.lowercased(),
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return .module
        }
        return bundle
    }
}

enum AppErrorMessage: Equatable, Sendable {
    case missingAuthFile
    case unreadableAuthFile
    case invalidAuthFile
    case missingAccessToken
    case unauthorized
    case httpStatus(Int)
    case network
    case invalidResponse
    case unknown

    init(_ error: Error) {
        if let error = error as? CodexAuthError {
            switch error {
            case .missingFile: self = .missingAuthFile
            case .unreadableFile: self = .unreadableAuthFile
            case .invalidJSON: self = .invalidAuthFile
            case .missingAccessToken: self = .missingAccessToken
            }
        } else if let error = error as? CodexAPIError {
            switch error {
            case .unauthorized: self = .unauthorized
            case .httpStatus(let status): self = .httpStatus(status)
            case .network: self = .network
            case .invalidResponse: self = .invalidResponse
            }
        } else {
            self = .unknown
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch self {
        case .missingAuthFile:
            AppLocalizer.text("error.auth.missingFile", language: language)
        case .unreadableAuthFile:
            AppLocalizer.text("error.auth.unreadableFile", language: language)
        case .invalidAuthFile:
            AppLocalizer.text("error.auth.invalidFile", language: language)
        case .missingAccessToken:
            AppLocalizer.text("error.auth.missingToken", language: language)
        case .unauthorized:
            AppLocalizer.text("error.api.unauthorized", language: language)
        case .httpStatus(let status):
            AppLocalizer.text("error.api.httpStatus", language: language, status)
        case .network:
            AppLocalizer.text("error.api.network", language: language)
        case .invalidResponse:
            AppLocalizer.text("error.api.invalidResponse", language: language)
        case .unknown:
            AppLocalizer.text("error.api.unknown", language: language)
        }
    }
}
