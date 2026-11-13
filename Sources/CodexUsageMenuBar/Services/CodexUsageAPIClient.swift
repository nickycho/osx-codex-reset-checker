import Foundation

private final class DenyHTTPRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct CodexUsageAPIClient: Sendable {
    private let session: URLSession
    private let redirectDelegate: DenyHTTPRedirectDelegate
    private let baseURL = URL(string: "https://chatgpt.com/backend-api/wham/")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil

        let redirectDelegate = DenyHTTPRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    func fetchUsage(credentials: CodexCredentials) async throws -> UsageResponse {
        try await fetch("usage", credentials: credentials)
    }

    func fetchResetCredits(credentials: CodexCredentials) async throws -> ResetCreditsResponse {
        try await fetch("rate-limit-reset-credits", credentials: credentials)
    }

    private func fetch<Response: Decodable>(
        _ path: String,
        credentials: CodexCredentials
    ) async throws -> Response {
        var request = URLRequest(
            url: baseURL.appendingPathComponent(path),
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CodexAPIError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw CodexAPIError.unauthorized
            }
            throw CodexAPIError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw CodexAPIError.invalidResponse
        }
    }
}

enum CodexAPIError: Error {
    case unauthorized
    case httpStatus(Int)
    case network
    case invalidResponse

}
