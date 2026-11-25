import AppKit
import ChatArchiveCore
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ArchiveStore()

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.archives.isEmpty {
                emptyState
            } else {
                ScrollView {
                    archiveList
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 620, minHeight: 420)
        .onAppear { store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refresh()
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("好", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            logo
            Text("微信记录")
                .font(.system(size: 24, weight: .semibold))
            Spacer(minLength: 18)
            statusIcon
            iconButton("folder", help: "打开下载文件夹") {
                store.openFolder()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private var logo: some View {
        Group {
            if let icon = Self.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ChatArchiveTheme.accent)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private static let appIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    @ViewBuilder
    private var statusIcon: some View {
        if !store.shareEntryInstalled {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
                .help("分享入口未注册")
                .padding(.trailing, 2)
        }
    }

    private func iconButton(
        _ systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(0.055)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var archiveList: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.archives.enumerated()), id: \.element.id) { index, archive in
                ArchiveRow(archive: archive) {
                    store.reveal(archive)
                } onCopyPath: {
                    store.copyPath(archive)
                }
                if index < store.archives.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(cardBorder)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text("暂无存档")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
    }
}

private struct ArchiveRow: View {
    let archive: ArchiveFile
    let onReveal: () -> Void
    let onCopyPath: () -> Void

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ChatArchiveTheme.accent.opacity(0.1))
                Image(systemName: archive.url.pathExtension.lowercased() == "zip" ? "doc.zipper" : "doc.text")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ChatArchiveTheme.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(archive.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            HStack(spacing: 12) {
                ShareServiceButton(url: archive.url, help: "转发到其他应用")
                    .frame(width: 14, height: 14)

                Button {
                    onCopyPath()
                    didCopy = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        didCopy = false
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(didCopy ? ChatArchiveTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
                .help("复制文件地址")

                Button(action: onReveal) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("在访达中显示")
            }
            .opacity(isHovering ? 1 : 0.55)

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isHovering ? Color.primary.opacity(0.035) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: onReveal)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(archive.modifiedAt) {
            return "今天 \(archive.modifiedAt.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInYesterday(archive.modifiedAt) {
            return "昨天 \(archive.modifiedAt.formatted(date: .omitted, time: .shortened))"
        }
        return archive.modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }
}
