import AppKit
import ChatArchiveCore
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ArchiveStore()

    var body: some View {
        VStack(spacing: 0) {
            if !store.shareEntryInstalled {
                registrationBanner
            }
            if store.archives.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    archiveList
                        .padding(.horizontal, 20)
                        .padding(.top, 52)
                        .padding(.bottom, 20)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 540, minHeight: 380)
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

    private var registrationBanner: some View {
        HStack(spacing: 8) {
            LucideIcon(name: "triangle-alert", size: 13)
                .foregroundStyle(.orange)
            Text("分享入口未注册")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 52)
    }

    private var archiveList: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.archives.enumerated()), id: \.element.id) { index, archive in
                ArchiveRow(
                    archive: archive,
                    onReveal: { store.reveal(archive) },
                    onCopyPath: { store.copyPath(archive) },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.delete(archive)
                        }
                    }
                )
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
    }
}

private struct EmptyStateView: View {
    @State private var faceIndex = 0
    @State private var bubbleFloat = false
    @State private var contentAppeared = false

    private static let faces = [
        "(￣▽￣)",
        "(・ω・)ノ",
        "(｡･ω･｡)",
        "(￣ω￣;)",
        "( ´ ▽ ` )",
    ]

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ChatArchiveTheme.accent.opacity(0.09))
                    .frame(width: 104, height: 104)
                    .scaleEffect(bubbleFloat ? 1.02 : 0.98)
                LucideIcon(name: "message-square-text", size: 42)
                    .foregroundStyle(ChatArchiveTheme.accent)
                    .offset(y: bubbleFloat ? -2.5 : 2.5)
                    .rotationEffect(.degrees(bubbleFloat ? 1.2 : -1.2))
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("这里还很安静")
                    .font(.system(size: 15, weight: .medium))
                Text(Self.faces[faceIndex])
                    .font(.system(size: 13, design: .monospaced))
                    .contentTransition(.opacity)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentAppeared = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                bubbleFloat = true
            }
        }
        .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                faceIndex = (faceIndex + 1) % Self.faces.count
            }
        }
    }
}

private struct ArchiveRow: View {
    let archive: ArchiveFile
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ChatArchiveTheme.accent.opacity(0.1))
                LucideIcon(
                    name: archive.url.pathExtension.lowercased() == "zip" ? "file-archive" : "file-text",
                    size: 14
                )
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

            HStack(spacing: 8) {
                ShareServiceButton(url: archive.url, help: "转发到其他应用")
                    .frame(width: 20, height: 20)

                Button {
                    onCopyPath()
                    didCopy = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        didCopy = false
                    }
                } label: {
                    LucideIcon(name: didCopy ? "check" : "copy", size: 14)
                        .foregroundStyle(didCopy ? ChatArchiveTheme.accent : .secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("复制文件地址")

                Button(action: onReveal) {
                    LucideIcon(name: "folder-open", size: 14)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("在访达中显示")

                Button(action: onDelete) {
                    LucideIcon(name: "trash-2", size: 14)
                        .foregroundStyle(isHovering ? Color.red.opacity(0.8) : .secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("移到废纸篓")
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
