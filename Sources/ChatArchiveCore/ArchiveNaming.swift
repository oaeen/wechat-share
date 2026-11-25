import Foundation

public enum ArchiveNaming {
    public static let fallbackStem = "聊天记录"
    public static let maximumNameBytes = 180

    private static let genericStems: Set<String> = [
        "archive", "chat", "chat history", "chat transcript", "history",
        "messages", "wechat", "weixin", "zip", "zip archive", "zip归档",
        "微信", "微信聊天记录", "微信记录", "归档", "聊天归档", "聊天记录",
        "聊天历史", "记录",
    ]

    public static func destinationName(
        sourceName: String?,
        fallbackExtension: String? = nil,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let raw = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let extensionName = preferredExtension(for: raw, fallback: fallbackExtension)
        var stem = sanitizedStem(raw)

        if stem.isEmpty || isGeneric(stem) {
            stem = "\(fallbackStem)-\(timestamp(now, timeZone: timeZone))"
        }

        stem = escapingReservedDevice(stem)
        let suffix = extensionName.isEmpty ? "" : ".\(extensionName)"
        let budget = maximumNameBytes - suffix.utf8.count
        stem = shortened(stem, byteLimit: budget)
        return stem + suffix
    }

    public static func uniqueName(for name: String, existing: Set<String>) -> String {
        let normalizedExisting = Set(existing.map { $0.lowercased() })
        guard normalizedExisting.contains(name.lowercased()) else { return name }

        let url = URL(fileURLWithPath: name)
        let extensionName = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        for index in 2...9999 {
            let suffix = extensionName.isEmpty ? "-\(index)" : "-\(index).\(extensionName)"
            let candidate = stem + suffix
            if !normalizedExisting.contains(candidate.lowercased()) {
                return candidate
            }
        }
        return "\(stem)-\(UUID().uuidString.prefix(8))\(extensionName.isEmpty ? "" : ".\(extensionName)")"
    }

    public static func sanitizedStem(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:<>\"|?*")
        var result = ""
        var pendingSeparator = false

        for scalar in raw.precomposedStringWithCanonicalMapping.unicodeScalars {
            let category = scalar.properties.generalCategory
            let shouldReplace = forbidden.contains(scalar)
                || scalar.value == 0
                || [.control, .format, .lineSeparator, .paragraphSeparator].contains(category)

            if shouldReplace {
                pendingSeparator = !result.isEmpty
                continue
            }
            if pendingSeparator {
                result.append("_")
                pendingSeparator = false
            }
            result.unicodeScalars.append(scalar)
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let stem = (trimmed as NSString).deletingPathExtension
        return stem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func preferredExtension(for raw: String, fallback: String?) -> String {
        let sourceExtension = (raw as NSString).pathExtension
        let candidate = sourceExtension.isEmpty ? (fallback ?? "") : sourceExtension
        let cleaned = candidate
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return String(cleaned.prefix(16))
    }

    private static func isGeneric(_ stem: String) -> Bool {
        let normalized = stem
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        return genericStems.contains(normalized)
    }

    private static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func escapingReservedDevice(_ name: String) -> String {
        let base = name.split(separator: ".", maxSplits: 1).first.map(String.init)?.uppercased() ?? ""
        let devices = Set(
            ["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"]
                + (1...9).flatMap { ["COM\($0)", "LPT\($0)"] }
        )
        return devices.contains(base) ? "_" + name : name
    }

    private static func shortened(_ source: String, byteLimit: Int) -> String {
        guard source.utf8.count > byteLimit else { return source }
        let ellipsis = "…"
        guard byteLimit > ellipsis.utf8.count else {
            return String(ellipsis.prefix(max(1, byteLimit / 2)))
        }

        var result = ""
        var bytes = 0
        for character in source {
            let count = String(character).utf8.count
            if bytes + count > byteLimit - ellipsis.utf8.count { break }
            result.append(character)
            bytes += count
        }
        return result.isEmpty ? fallbackStem : result + ellipsis
    }
}
