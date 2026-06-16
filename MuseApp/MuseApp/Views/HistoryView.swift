// HistoryView.swift — Browse past sessions

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \StoredChatSession.createdAt, order: .reverse) private var sessions: [StoredChatSession]
    @Environment(\.modelContext) private var modelContext
    @State private var showClearConfirm = false

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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.prompt)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                Text(session.answer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(session.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
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
        }
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
