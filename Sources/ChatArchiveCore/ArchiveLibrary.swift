import Foundation

public struct ArchiveFile: Identifiable, Hashable, Sendable {
    public let url: URL
    public let byteCount: Int64
    public let modifiedAt: Date

    public var id: String { url.path }

    public init(url: URL, byteCount: Int64, modifiedAt: Date) {
        self.url = url
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }
}

public struct ArchiveLibrary: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func files(limit: Int = 80) throws -> [ArchiveFile] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else { return [] }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        let archives = urls.compactMap { url -> ArchiveFile? in
            guard !url.lastPathComponent.hasSuffix(".part") else { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            guard values.isRegularFile == true else { return nil }
            return ArchiveFile(
                url: url,
                byteCount: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
        }
        .sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedDescending
            }
            return $0.modifiedAt > $1.modifiedAt
        }

        return Array(archives.prefix(max(0, limit)))
    }
}
