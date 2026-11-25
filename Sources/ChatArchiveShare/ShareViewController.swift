import AppKit
import ChatArchiveCore
import Foundation
import OSLog
import UniformTypeIdentifiers

@objc(CAShareViewController)
final class ShareViewController: NSViewController {
    private let logger = Logger(subsystem: "dev.chatarchive.app", category: "share")
    private var hasStarted = false

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        view.alphaValue = 0
        self.view = view
        preferredContentSize = .zero
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard !hasStarted, let context = extensionContext else { return }
        hasStarted = true
        Task { @MainActor in
            await receive(context: context)
        }
    }

    @MainActor
    private func receive(context: NSExtensionContext) async {
        do {
            let providers = Self.inputProviders(from: context.inputItems)
            guard !providers.isEmpty else {
                throw ShareError.noFiles
            }

            let directory = try ChatArchiveLocation.archiveDirectory(create: true)
            let saver = ArchiveSaver(directory: directory)
            let now = Date()
            for provider in providers {
                try await save(provider: provider, with: saver, now: now)
            }
            context.completeRequest(returningItems: nil, completionHandler: nil)
        } catch {
            logger.error("Share failed: \(error.localizedDescription, privacy: .public)")
            present(error: error)
            context.cancelRequest(
                withError: NSError(
                    domain: "dev.chatarchive.app.share",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                )
            )
        }
    }

    private func save(provider: NSItemProvider, with saver: ArchiveSaver, now: Date) async throws {
        guard let representation = ShareRepresentation.choose(from: provider.registeredTypeIdentifiers) else {
            throw ShareError.unsupportedType
        }
        let name = await originalName(from: provider)
        let fallbackExtension = UTType(representation.typeIdentifier)?.preferredFilenameExtension ?? "zip"

        switch representation.strategy {
        case .fileRepresentation:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                provider.loadFileRepresentation(
                    forTypeIdentifier: representation.typeIdentifier
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let url else {
                        continuation.resume(throwing: ShareError.noFiles)
                        return
                    }
                    do {
                        _ = try saver.save(
                            sourceURL: url,
                            suggestedName: name,
                            fallbackExtension: fallbackExtension,
                            now: now
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        case .fileURL:
            let url = try await loadFileURL(provider: provider, typeIdentifier: representation.typeIdentifier)
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var coordinationError: NSError?
            var saveError: Error?
            NSFileCoordinator().coordinate(
                readingItemAt: url,
                options: [.withoutChanges],
                error: &coordinationError
            ) { coordinatedURL in
                do {
                    _ = try saver.save(
                        sourceURL: coordinatedURL,
                        suggestedName: name,
                        fallbackExtension: fallbackExtension,
                        now: now
                    )
                } catch {
                    saveError = error
                }
            }
            if let coordinationError { throw coordinationError }
            if let saveError { throw saveError }
        }
    }

    private func loadFileURL(provider: NSItemProvider, typeIdentifier: String) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            provider.loadObject(ofClass: NSURL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = object as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.noFiles)
                }
            }
        }
    }

    private func originalName(from provider: NSItemProvider) async -> String? {
        if let suggested = provider.suggestedName, !suggested.isEmpty {
            return suggested
        }
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }
        let url: URL? = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            provider.loadObject(ofClass: NSURL.self) { object, _ in
                continuation.resume(returning: object as? URL)
            }
        }
        guard let url, !url.lastPathComponent.isEmpty else { return nil }
        return url.lastPathComponent
    }

    private static func inputProviders(from inputItems: [Any]) -> [NSItemProvider] {
        inputItems.flatMap { item -> [NSItemProvider] in
            guard let extensionItem = item as? NSExtensionItem else { return [] }
            return extensionItem.attachments ?? []
        }
    }

    @MainActor
    private func present(error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "没有保存"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

private enum ShareError: LocalizedError {
    case noFiles
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "分享中没有可保存的文件。"
        case .unsupportedType:
            return "这个分享内容不是可保存的文件。"
        }
    }
}
