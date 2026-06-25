// SidebarView.swift — Persistent left pane: new chat, recent threads, settings.

import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var engine: MuseEngine
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @Query private var allSessions: [StoredChatSession]
    @State private var showSettings = false

    var body: some View {
        List {
            Section {
                Button {
                    startOrReuseEmptyThread()
                    collapseOniPhone()
                } label: {
                    Label("New chat", systemImage: "square.and.pencil")
                        .font(.body.weight(.medium))
                }
            }

            if !threads.isEmpty {
                Section("Recent") {
                    ForEach(threads) { thread in
                        Button {
                            engine.switchToThread(thread.id)
                            collapseOniPhone()
                        } label: {
                            row(thread)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteThreads)
                }
            }

            Section {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chats")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func collapseOniPhone() {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            preferredCompactColumn = .detail
        }
        #endif
    }

    private func row(_ thread: ChatThread) -> some View {
        let isActive = thread.id == engine.currentThreadID
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isActive ? Color.blue : Color.clear)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.subheadline.weight(isActive ? .semibold : .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(thread.updatedAt, style: .relative)
                    Text("·")
                    Text("\(sessionCount(thread.id)) messages")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func sessionCount(_ threadID: UUID) -> Int {
        allSessions.filter { $0.threadID == threadID }.count
    }

    /// Avoids piling up empty "New chat" threads when the user taps repeatedly.
    /// If the active thread has no messages yet, reuse it; otherwise create one.
    private func startOrReuseEmptyThread() {
        if let id = engine.currentThreadID, sessionCount(id) == 0 { return }
        engine.startNewThread(modelContext: modelContext)
    }

    private func deleteThreads(at offsets: IndexSet) {
        for index in offsets {
            let thread = threads[index]
            for session in allSessions where session.threadID == thread.id {
                modelContext.delete(session)
            }
            if engine.currentThreadID == thread.id {
                engine.currentThreadID = nil
            }
            modelContext.delete(thread)
        }
    }
}
