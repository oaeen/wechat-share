import AppKit
import Foundation

final class ShareDelegate: NSObject, NSSharingServiceDelegate {
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        print("shared")
        NSApp.terminate(nil)
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        FileHandle.standardError.write(Data("share failed: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: share-test.swift <file>\n".utf8))
    exit(2)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let services = NSSharingService.sharingServices(forItems: [url])
guard let service = services.first(where: { $0.title == "微信记录" }) else {
    FileHandle.standardError.write(Data("share service not found\n".utf8))
    exit(2)
}

let delegate = ShareDelegate()
service.delegate = delegate
DispatchQueue.main.async {
    service.perform(withItems: [url])
}
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    FileHandle.standardError.write(Data("share timed out\n".utf8))
    exit(3)
}
app.run()
