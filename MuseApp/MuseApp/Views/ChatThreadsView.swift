import SwiftData
import SwiftUI

struct ChatThreadsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var engine: MuseEngine
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @Query private var allSessions: [StoredChatSession]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        engine.startNewThread(modelContext: modelContext)
                        dismiss()
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                            .font(.body.weight(.medium))
                    }
                }

                if !threads.isEmpty {
                    Section("Recent") {
                        ForEach(threads) { thread in
                            Button { selectThread(thread) } label: {
                                row(thread)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteThreads)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Chats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
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

    private func selectThread(_ thread: ChatThread) {
        engine.switchToThread(thread.id)
        dismiss()
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
