import Foundation

enum SharedSnapshotStore {
    static let appGroupIdentifier = "X9MB8SQZHF.com.Zamisku.CodexQuota.shared"
    private static let fileName = "quota-snapshot.json"
    private static let maximumBytes = 128 * 1024

    static func save(_ snapshot: ProviderSnapshot) throws {
        guard let url = snapshotURL else { throw StoreError.groupUnavailable }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= maximumBytes else { throw StoreError.snapshotTooLarge }
        try data.write(to: url, options: .atomic)
    }

    static func load() -> ProviderSnapshot? {
        guard let url = snapshotURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = (attributes[.size] as? NSNumber)?.intValue,
              size <= maximumBytes,
              let data = try? Data(contentsOf: url),
              data.count <= maximumBytes else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProviderSnapshot.self, from: data)
    }

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    enum StoreError: Error {
        case groupUnavailable
        case snapshotTooLarge
    }
}
