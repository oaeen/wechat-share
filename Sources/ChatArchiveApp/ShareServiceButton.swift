import AppKit
import SwiftUI

struct ShareServiceButton: NSViewRepresentable {
    let url: URL
    let help: String

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.focusRingType = .none
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        button.image = resizedIcon(named: "share-2", size: 14)
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = help
        button.target = context.coordinator
        button.action = #selector(Coordinator.showPicker(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.url = url
        button.toolTip = help
    }

    private func resizedIcon(named name: String, size: CGFloat) -> NSImage? {
        guard let source = LucideAssets.image(named: name) else { return nil }
        let target = NSImage(size: NSSize(width: size, height: size))
        target.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        target.unlockFocus()
        target.isTemplate = true
        return target
    }

    final class Coordinator: NSObject, NSSharingServicePickerDelegate {
        var url: URL
        private var picker: NSSharingServicePicker?

        init(url: URL) {
            self.url = url
        }

        @objc func showPicker(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: [url])
            picker.delegate = self
            self.picker = picker
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            picker = nil
        }
    }
}
