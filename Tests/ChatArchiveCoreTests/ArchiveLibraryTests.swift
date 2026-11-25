import Foundation
import XCTest
@testable import ChatArchiveCore

final class ArchiveLibraryTests: XCTestCase {
    func testListsVisibleFilesNewestFirstAndSkipsPartial() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatArchiveLibraryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let old = root.appendingPathComponent("old.zip")
        let new = root.appendingPathComponent("new.zip")
        let partial = root.appendingPathComponent(".unfinished.part")
        try Data("old".utf8).write(to: old)
        try Data("new".utf8).write(to: new)
        try Data("partial".utf8).write(to: partial)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: old.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: new.path
        )

        let files = try ArchiveLibrary(directory: root).files()

        XCTAssertEqual(files.map(\.url.lastPathComponent), ["new.zip", "old.zip"])
        XCTAssertEqual(files.first?.byteCount, 3)
    }
}
