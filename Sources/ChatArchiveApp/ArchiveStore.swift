import AppKit
import ChatArchiveCore
import Foundation

@MainActor
final class ArchiveStore: ObservableObject {
    static let shareExtensionIdentifier = "dev.chatarchive.app.share"

    @Published private(set) var archives: [ArchiveFile] = []
    @Published private(set) var folderURL: URL
    @Published private(set) var shareEntryInstalled = false
    @Published var errorMessage: String?

    init() {
        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(ChatArchiveLocation.folderName, isDirectory: true)
        if let directory = try? ChatArchiveLocation.archiveDirectory(create: true) {
            folderURL = directory
        } else {
            folderURL = fallback
            errorMessage = "无法创建下载文件夹。"
        }
        shareEntryInstalled = Self.isShareEntryRegistered()
        refresh()
    }

    func refresh() {
        do {
            archives = try ArchiveLibrary(directory: folderURL).files()
        } catch {
            errorMessage = error.localizedDescription
        }
        shareEntryInstalled = Self.isShareEntryRegistered()
    }

    func openFolder() {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folderURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reveal(_ archive: ArchiveFile) {
        NSWorkspace.shared.activateFileViewerSelecting([archive.url])
    }

    func copyPath(_ archive: ArchiveFile) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(archive.url.path, forType: .string)
    }

    func clearError() {
        errorMessage = nil
    }

    private static func isShareEntryRegistered() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-p", "com.apple.share-services", "-i", shareExtensionIdentifier]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return process.terminationStatus == 0 && output.contains(shareExtensionIdentifier)
        } catch {
            return false
        }
    }
}
