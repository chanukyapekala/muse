import SwiftData
import SwiftUI

struct ChatSessionsView: View {
    let category: String
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var engine: MuseEngine
    @Query private var sessions: [StoredChatSession]
    @State private var selected: StoredChatSession?

    init(category: String) {
        self.category = category
        _sessions = Query(
            filter: #Predicate<StoredChatSession> { $0.category == category },
            sort: [SortDescriptor(\StoredChatSession.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessions) { s in
                        Button { selected = s } label: { row(s) }
                            .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selected) { s in
            ChatSessionDetailView(session: s) { prompt in
                engine.pendingPrompt = prompt
                engine.selectedTab = 0
                selected = nil
            }
        }
    }

    private func row(_ s: StoredChatSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.prompt)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(s.createdAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(sessions[i]) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No \(category) conversations yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Enable chat history in Settings to keep records.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

struct ChatSessionDetailView: View {
    let session: StoredChatSession
    let onContinue: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    label("You asked")
                    Text(session.prompt)
                        .font(.body.weight(.medium))

                    Divider()

                    label("Muse replied")
                    Text(session.answer)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(20)
            }
            .navigationTitle(session.createdAt.formatted(date: .abbreviated, time: .shortened))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { onContinue(session.prompt) }
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
