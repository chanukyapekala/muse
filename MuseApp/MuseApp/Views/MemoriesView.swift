import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MemoriesView: View {
    @Query(sort: \Memory.createdAt, order: .reverse) private var memories: [Memory]
    @Query private var clusters: [MemoryCluster]
    @Environment(\.modelContext) private var modelContext

    @State private var showResetConfirm = false
    @State private var editingMemory: Memory?
    @State private var editText = ""
    @State private var showExporter = false
    @State private var exportDocument: MemoryExportDocument?

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(clusterGroups, id: \.id) { group in
                                clusterCard(group)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Memory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            #endif
            .confirmationDialog("Reset all memory?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive, action: resetAll)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Muse will forget everything it knows about you.")
            }
            .sheet(item: $editingMemory) { memory in
                editSheet(memory)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "muse-memory"
            ) { _ in }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No memories yet")
                .font(.title3.weight(.semibold))
            Text("Muse learns about you as you chat and uses that context in future conversations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Cluster card

    private func clusterCard(_ group: ClusterGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(group.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(group.memories.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 14)

            // Memory rows
            ForEach(group.memories) { memory in
                memoryRow(memory)
                if memory.id != group.memories.last?.id {
                    Divider()
                        .padding(.leading, 54)
                }
            }
        }
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Memory row

    private func memoryRow(_ memory: Memory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { memory.active },
                set: { memory.active = $0 }
            ))
            .labelsHidden()
            .tint(.blue)
            .padding(.top, 1)

            Text(memory.fact)
                .font(.subheadline)
                .foregroundStyle(memory.active ? .primary : .tertiary)
                .strikethrough(!memory.active, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(memory)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editText = memory.fact
                editingMemory = memory
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !memories.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    prepareExport()
                    showExporter = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    showResetConfirm = true
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Edit sheet

    private func editSheet(_ memory: Memory) -> some View {
        NavigationStack {
            Form {
                Section("Edit memory") {
                    TextField("Fact", text: $editText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingMemory = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { memory.fact = trimmed }
                        editingMemory = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Cluster grouping

    private struct ClusterGroup: Identifiable {
        let id: UUID
        let label: String
        let memories: [Memory]
    }

    private var clusterGroups: [ClusterGroup] {
        let clusterMap = Dictionary(uniqueKeysWithValues: clusters.map { ($0.id, $0.label) })
        let grouped = Dictionary(grouping: memories, by: \.clusterID)
        return grouped.map { id, mems in
            ClusterGroup(
                id: id,
                label: clusterMap[id]?.capitalized ?? "General",
                memories: mems.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { $0.label < $1.label }
    }

    // MARK: - Export

    private func prepareExport() {
        let clusterMap = Dictionary(uniqueKeysWithValues: clusters.map { ($0.id, $0.label) })
        let records = memories.map { m in
            MemoryExport.MemoryRecord(
                id: m.id,
                fact: m.fact,
                topic: clusterMap[m.clusterID] ?? "general",
                createdAt: m.createdAt,
                active: m.active
            )
        }
        exportDocument = MemoryExportDocument(export: MemoryExport(exportedAt: Date(), memories: records))
    }

    // MARK: - Reset

    private func resetAll() {
        memories.forEach { modelContext.delete($0) }
        clusters.forEach { modelContext.delete($0) }
    }
}

// MARK: - FileDocument

struct MemoryExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let export: MemoryExport

    init(export: MemoryExport) { self.export = export }

    init(configuration: ReadConfiguration) throws {
        export = MemoryExport(exportedAt: Date(), memories: [])
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        return FileWrapper(regularFileWithContents: data)
    }
}
