// HistoryView.swift — Browse past sessions

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var engine: MuseEngine
    @State private var sessions: [MuseResponse] = []

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Your conversations will appear here.")
                    )
                } else {
                    List(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.prompt)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            HStack {
                                if let score = session.trustScore {
                                    Text("Trust: \(Int(score * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(session.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
