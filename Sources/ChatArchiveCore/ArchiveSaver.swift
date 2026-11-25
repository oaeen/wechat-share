import Foundation

public struct ArchiveSaver: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    @discardableResult
    public func save(
        sourceURL: URL,
        suggestedName: String?,
        fallbackExtension: String? = nil,
        now: Date = Date()
    ) throws -> URL {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw ChatArchiveError.sourceMissing(sourceURL.lastPathComponent)
        }
        guard !isDirectory.boolValue else {
            throw ChatArchiveError.sourceIsNotAFile(sourceURL.lastPathComponent)
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ChatArchiveError.saveFailed(error.localizedDescription)
        }

        var existing = Set(
            (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        )
        let requestedName = ArchiveNaming.destinationName(
            sourceName: suggestedName,
            fallbackExtension: fallbackExtension,
            now: now
        )
        let partial = directory.appendingPathComponent(".\(UUID().uuidString).part")

        do {
            try fileManager.copyItem(at: sourceURL, to: partial)
        } catch {
            throw ChatArchiveError.saveFailed(error.localizedDescription)
        }

        defer {
            if fileManager.fileExists(atPath: partial.path) {
                try? fileManager.removeItem(at: partial)
            }
        }

        for _ in 0..<32 {
            let name = ArchiveNaming.uniqueName(for: requestedName, existing: existing)
            let destination = directory.appendingPathComponent(name)
            do {
                try fileManager.moveItem(at: partial, to: destination)
                return destination
            } catch {
                if fileManager.fileExists(atPath: destination.path) {
                    existing.insert(name)
                    continue
                }
                throw ChatArchiveError.saveFailed(error.localizedDescription)
            }
        }

        throw ChatArchiveError.saveFailed("同名文件过多，请稍后重试。")
    }
}
