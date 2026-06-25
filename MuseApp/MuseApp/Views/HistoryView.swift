// HistoryView.swift — Browse past sessions

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \StoredChatSession.createdAt, order: .reverse) private var sessions: [StoredChatSession]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var engine: MuseEngine
    @State private var showClearConfirm = false
    @State private var selected: StoredChatSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Enable \"Save chat history\" in Settings, then your conversations will appear here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button { selected = session } label: { row(session) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            showClearConfirm = true
                        }
                    }
                }
            }
            #endif
            .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive, action: clearAll)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(item: $selected) { s in
                ChatSessionDetailView(session: s) { prompt in
                    engine.pendingPrompt = prompt
                    engine.selectedTab = 0
                    selected = nil
                }
            }
        }
    }

    private func row(_ session: StoredChatSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let category = session.category {
                    categoryBadge(category)
                }
                Text(session.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(session.prompt)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Text(session.answer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func categoryBadge(_ category: String) -> some View {
        let color = AuraNode(id: UUID(), label: category, count: 0, embedding: [], position: .zero).color
        return Text(category)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }

    private func clearAll() {
        for session in sessions {
            modelContext.delete(session)
        }
    }
}
