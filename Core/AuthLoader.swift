import Foundation

struct CodexAuth: Sendable {
    let accessToken: String
    let accountID: String?
}

enum AuthLoader {
    private static let maximumAuthBytes = 256 * 1024

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> CodexAuth {
        let baseURL: URL
        if let customHome = environment["CODEX_HOME"], customHome.hasPrefix("/") {
            baseURL = URL(fileURLWithPath: customHome, isDirectory: true)
        } else {
            baseURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
        }
        let url = baseURL.appendingPathComponent("auth.json", isDirectory: false)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let handle = try? FileHandle(forReadingFrom: url) else {
            throw QuotaFailure.loginNotFound
        }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumAuthBytes + 1),
              data.count <= maximumAuthBytes,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaFailure.invalidLogin
        }

        let tokens = (root["tokens"] as? [String: Any]) ?? root
        guard let token = pickString(tokens, keys: ["access_token", "accessToken"]),
              isSafeHeaderValue(token) else {
            throw QuotaFailure.loginExpired
        }
        let accountID = pickString(tokens, keys: ["account_id", "accountId"])
            ?? accountIDFromJWT(token)
        if let accountID, !isSafeHeaderValue(accountID) { throw QuotaFailure.invalidLogin }
        return CodexAuth(accessToken: token, accountID: accountID)
    }

    private static func pickString(_ dictionary: [String: Any], keys: [String]) -> String? {
        keys.lazy.compactMap { dictionary[$0] as? String }.first
    }

    private static func accountIDFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return pickString(
            object,
            keys: [
                "https://api.openai.com/auth.chatgpt_account_id",
                "chatgpt_account_id"
            ]
        )
    }

    private static func isSafeHeaderValue(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F }
    }
}
