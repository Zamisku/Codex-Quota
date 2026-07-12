import Foundation

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
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

actor CodexQuotaService {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let creditsURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    private static let maximumResponseBytes = 1024 * 1024

    private let redirectDelegate: NoRedirectDelegate
    private let session: URLSession

    init() {
        let delegate = NoRedirectDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpAdditionalHeaders = ["User-Agent": "CodexQuotaWidget/2.0"]
        redirectDelegate = delegate
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    func fetchSnapshot() async -> ProviderSnapshot {
        do {
            let auth = try AuthLoader.load()
            async let usageResult = fetch(Self.usageURL, auth: auth, required: true)
            async let creditsResult = fetch(Self.creditsURL, auth: auth, required: false)
            let (usageData, creditsData) = try await (usageResult, creditsResult)
            guard let usageData else { throw QuotaFailure.serviceUnavailable }
            return try QuotaResponseParser.parse(usageData: usageData, creditsData: creditsData)
        } catch let failure as QuotaFailure {
            return .failure(failure)
        } catch {
            return .failure(.networkUnavailable)
        }
    }

    private func fetch(_ url: URL, auth: CodexAuth, required: Bool) async throws -> Data? {
        guard url.scheme == "https", url.host == "chatgpt.com" else {
            throw QuotaFailure.serviceUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        if let accountID = auth.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                if required { throw QuotaFailure.serviceUnavailable }
                return nil
            }
            guard (200 ... 299).contains(http.statusCode) else {
                if !required { return nil }
                switch http.statusCode {
                case 401, 403: throw QuotaFailure.loginExpired
                case 429: throw QuotaFailure.rateLimited
                default: throw QuotaFailure.serviceUnavailable
                }
            }
            guard http.expectedContentLength < 0
                    || http.expectedContentLength <= Self.maximumResponseBytes else {
                if required { throw QuotaFailure.responseChanged }
                return nil
            }
            var data = Data()
            if http.expectedContentLength > 0 { data.reserveCapacity(Int(http.expectedContentLength)) }
            for try await byte in bytes {
                guard data.count < Self.maximumResponseBytes else {
                    if required { throw QuotaFailure.responseChanged }
                    return nil
                }
                data.append(byte)
            }
            return data
        } catch let failure as QuotaFailure {
            throw failure
        } catch {
            if required { throw QuotaFailure.networkUnavailable }
            return nil
        }
    }
}
