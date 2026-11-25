import Foundation

public enum ChatArchiveLocation {
    public static let folderName = "聊天存档"

    public static func downloadsDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw ChatArchiveError.downloadsUnavailable
        }
        return downloads
    }

    public static func archiveDirectory(
        create: Bool = false,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try downloadsDirectory(fileManager: fileManager)
            .appendingPathComponent(folderName, isDirectory: true)
        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

public enum ChatArchiveError: LocalizedError {
    case downloadsUnavailable
    case sourceMissing(String)
    case sourceIsNotAFile(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .downloadsUnavailable:
            return "找不到“下载”文件夹。"
        case .sourceMissing(let name):
            return "分享的文件已经不存在：\(name)"
        case .sourceIsNotAFile(let name):
            return "分享的内容不是文件：\(name)"
        case .saveFailed(let reason):
            return "保存失败：\(reason)"
        }
    }
}
