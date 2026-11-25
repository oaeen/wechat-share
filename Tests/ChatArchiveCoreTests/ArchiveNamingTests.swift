import XCTest
@testable import ChatArchiveCore

final class ArchiveNamingTests: XCTestCase {
    private let timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    func testKeepsReadableSourceNameAndExtension() {
        let name = ArchiveNaming.destinationName(
            sourceName: "示例群聊.zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertEqual(name, "示例群聊.zip")
    }

    func testReplacesGenericNameWithTimestamp() {
        let name = ArchiveNaming.destinationName(
            sourceName: "聊天记录.zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertTrue(name.hasPrefix("聊天记录-"))
        XCTAssertTrue(name.hasSuffix(".zip"))
        XCTAssertNotEqual(name, "聊天记录.zip")
    }

    func testUsesZipExtensionWhenProviderHasNoName() {
        let name = ArchiveNaming.destinationName(
            sourceName: nil,
            fallbackExtension: "zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertTrue(name.hasPrefix("聊天记录-"))
        XCTAssertTrue(name.hasSuffix(".zip"))
    }

    func testSanitizesPathAndControlCharacters() {
        let name = ArchiveNaming.destinationName(
            sourceName: "group/name\u{0}:\"test\".zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("\u{0}"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertTrue(name.hasSuffix(".zip"))
    }

    func testTruncatesLongUnicodeNameAtCharacterBoundary() {
        let name = ArchiveNaming.destinationName(
            sourceName: String(repeating: "超长聊天名称", count: 80) + ".zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertLessThanOrEqual(name.utf8.count, ArchiveNaming.maximumNameBytes)
        XCTAssertTrue(name.hasSuffix(".zip"))
        XCTAssertTrue(name.contains("…"))
    }

    func testUniqueNamePreservesExtension() {
        let name = ArchiveNaming.uniqueName(
            for: "聊天记录.zip",
            existing: ["聊天记录.zip", "聊天记录-2.zip"]
        )
        XCTAssertEqual(name, "聊天记录-3.zip")
    }

    func testEscapesWindowsReservedDeviceName() {
        let name = ArchiveNaming.destinationName(
            sourceName: "CON.zip",
            now: date,
            timeZone: timeZone
        )
        XCTAssertEqual(name, "_CON.zip")
    }
}
