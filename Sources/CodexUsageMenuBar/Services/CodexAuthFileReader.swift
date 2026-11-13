import Foundation

struct CodexCredentials: Sendable {
    let accessToken: String
    let accountID: String?
}

struct CodexAuthFileReader {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json", isDirectory: false)
    }

    func loadCredentials() throws -> CodexCredentials {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CodexAuthError.missingFile
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw CodexAuthError.unreadableFile
        }

        let authFile: AuthFile
        do {
            authFile = try JSONDecoder().decode(AuthFile.self, from: data)
        } catch {
            throw CodexAuthError.invalidJSON
        }

        guard let accessToken = authFile.tokens?.accessToken,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexAuthError.missingAccessToken
        }

        return CodexCredentials(accessToken: accessToken, accountID: authFile.tokens?.accountID)
    }
}

private struct AuthFile: Decodable {
    let tokens: AuthTokens?
}

private struct AuthTokens: Decodable {
    let accessToken: String?
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accountID = "account_id"
    }
}

enum CodexAuthError: Error {
    case missingFile
    case unreadableFile
    case invalidJSON
    case missingAccessToken
}
