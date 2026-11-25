import Foundation
import XCTest
@testable import ChatArchiveCore

final class ArchiveSaverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSavesBytesAndRemovesPartialFile() throws {
        let source = root.appendingPathComponent("source.zip")
        let payload = Data("wechat archive".utf8)
        try payload.write(to: source)

        let directory = root.appendingPathComponent("Downloads/聊天存档", isDirectory: true)
        let saved = try ArchiveSaver(directory: directory).save(
            sourceURL: source,
            suggestedName: "群聊.zip"
        )

        XCTAssertEqual(try Data(contentsOf: saved), payload)
        XCTAssertEqual(saved.lastPathComponent, "群聊.zip")
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .contains { $0.hasSuffix(".part") }
        )
    }

    func testDoesNotOverwriteAnExistingArchive() throws {
        let first = root.appendingPathComponent("first.zip")
        let second = root.appendingPathComponent("second.zip")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let directory = root.appendingPathComponent("Downloads/聊天存档", isDirectory: true)
        let saver = ArchiveSaver(directory: directory)
        let firstSaved = try saver.save(sourceURL: first, suggestedName: "同名.zip")
        let secondSaved = try saver.save(sourceURL: second, suggestedName: "同名.zip")

        XCTAssertEqual(firstSaved.lastPathComponent, "同名.zip")
        XCTAssertEqual(secondSaved.lastPathComponent, "同名-2.zip")
        XCTAssertEqual(try Data(contentsOf: firstSaved), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: secondSaved), Data("second".utf8))
    }

    func testRejectsMissingSource() {
        let directory = root.appendingPathComponent("Downloads/聊天存档", isDirectory: true)
        XCTAssertThrowsError(
            try ArchiveSaver(directory: directory).save(
                sourceURL: root.appendingPathComponent("missing.zip"),
                suggestedName: "missing.zip"
            )
        )
    }
}
