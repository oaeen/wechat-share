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
        button.imageScaling = .scaleProportionallyDown
        button.image = NSImage(
            systemSymbolName: "square.and.arrow.up",
            accessibilityDescription: help
        )
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
