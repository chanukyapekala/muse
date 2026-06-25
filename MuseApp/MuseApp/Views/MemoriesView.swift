import SwiftData
import SwiftUI

// MARK: - Graph model

struct AuraNode: Identifiable {
    let id: UUID
    let label: String
    let count: Int
    let embedding: [Double]
    var position: CGPoint
    var velocity: CGVector = .zero

    var color: Color {
        // Deterministic hash → hue across full spectrum, pastel-bright.
        let palette: [Color] = [
            Color(red: 0.60, green: 0.35, blue: 0.95),
            Color(red: 0.35, green: 0.55, blue: 0.95),
            Color(red: 0.30, green: 0.70, blue: 0.55),
            Color(red: 0.95, green: 0.55, blue: 0.30),
            Color(red: 0.90, green: 0.40, blue: 0.50),
            Color(red: 0.95, green: 0.80, blue: 0.30),
            Color(red: 0.55, green: 0.45, blue: 1.00),
            Color(red: 0.40, green: 0.85, blue: 0.85),
            Color(red: 0.85, green: 0.45, blue: 0.85),
        ]
        let hash = label.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}

struct AuraEdge: Identifiable {
    let id: String
    let from: UUID
    let to: UUID
    let weight: Int
}

@MainActor
final class AuraViewModel: ObservableObject {
    @Published var nodes: [AuraNode] = []
    @Published var edges: [AuraEdge] = []

    private var timer: Timer?
    private let repulsion: CGFloat = 800
    private let attraction: CGFloat = 0.02
    private let damping: CGFloat = 0.85
    private let idealLength: CGFloat = 110

    func rebuild(from clusters: [MemoryCluster], persistedEdges: [ClusterEdge]) {
        let center = CGPoint(x: 400, y: 400)
        let existing = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
        var newNodes: [AuraNode] = []
        for (i, c) in clusters.enumerated() {
            let pos = existing[c.id] ?? {
                let angle = CGFloat(i) / CGFloat(max(clusters.count, 1)) * 2 * .pi
                let r: CGFloat = 100 + CGFloat.random(in: 0...60)
                return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            }()
            newNodes.append(AuraNode(id: c.id, label: c.label, count: c.count, embedding: c.embedding, position: pos))
        }
        nodes = newNodes
        let validIDs = Set(newNodes.map(\.id))
        edges = persistedEdges
            .filter { validIDs.contains($0.fromID) && validIDs.contains($0.toID) }
            .map { AuraEdge(id: $0.id.uuidString, from: $0.fromID, to: $0.toID, weight: $0.weight) }
        startSimulation()
    }

    func startSimulation() {
        timer?.invalidate()
        var iters = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            Task { @MainActor in
                self.step()
                iters += 1
                if iters > 300 { t.invalidate() }
            }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func step() {
        guard nodes.count > 1 else { return }
        var forces = Array(repeating: CGVector.zero, count: nodes.count)

        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let f = repulsion / (dist * dist)
                let fx = (dx / dist) * f, fy = (dy / dist) * f
                forces[i].dx += fx; forces[i].dy += fy
                forces[j].dx -= fx; forces[j].dy -= fy
            }
        }
        let idx = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) })
        for e in edges {
            guard let i = idx[e.from], let j = idx[e.to] else { continue }
            let dx = nodes[j].position.x - nodes[i].position.x
            let dy = nodes[j].position.y - nodes[i].position.y
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let f = (dist - idealLength) * attraction
            let fx = (dx / dist) * f, fy = (dy / dist) * f
            forces[i].dx += fx; forces[i].dy += fy
            forces[j].dx -= fx; forces[j].dy -= fy
        }
        let cx: CGFloat = 400, cy: CGFloat = 400
        for i in 0..<nodes.count {
            forces[i].dx += (cx - nodes[i].position.x) * 0.001
            forces[i].dy += (cy - nodes[i].position.y) * 0.001
        }
        for i in 0..<nodes.count {
            nodes[i].velocity.dx = (nodes[i].velocity.dx + forces[i].dx) * damping
            nodes[i].velocity.dy = (nodes[i].velocity.dy + forces[i].dy) * damping
            let speed = sqrt(nodes[i].velocity.dx * nodes[i].velocity.dx + nodes[i].velocity.dy * nodes[i].velocity.dy)
            if speed > 10 {
                nodes[i].velocity.dx *= 10 / speed
                nodes[i].velocity.dy *= 10 / speed
            }
            nodes[i].position.x += nodes[i].velocity.dx
            nodes[i].position.y += nodes[i].velocity.dy
        }
    }

    private func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 1.0 }
        return 1.0 - (dot / (magA * magB))
    }
}

// MARK: - AuraView

struct AuraView: View {
    @Query(sort: \MemoryCluster.lastSeen, order: .reverse) private var clusters: [MemoryCluster]
    @Query private var clusterEdges: [ClusterEdge]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = AuraViewModel()

    @State private var scale: CGFloat = 0.7
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedID: UUID?
    @State private var navPath: [String] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color.black.ignoresSafeArea()
                if clusters.isEmpty {
                    emptyState
                } else {
                    canvas
                }
            }
            .navigationTitle("Aura")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: String.self) { category in
                ChatSessionsView(category: category)
            }
            .onAppear { vm.rebuild(from: clusters, persistedEdges: clusterEdges) }
            .onChange(of: clusters.map(\.id)) { _, _ in vm.rebuild(from: clusters, persistedEdges: clusterEdges) }
            .onChange(of: clusterEdges.map(\.id)) { _, _ in vm.rebuild(from: clusters, persistedEdges: clusterEdges) }
            .onDisappear { vm.stop() }
        }
    }

    private var canvas: some View {
        GeometryReader { geo in
            let canvasCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Canvas { ctx, _ in
                let transform = CGAffineTransform(translationX: canvasCenter.x + offset.width,
                                                  y: canvasCenter.y + offset.height)
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: -400, y: -400)

                let nodeMap = Dictionary(uniqueKeysWithValues: vm.nodes.map { ($0.id, $0) })
                for e in vm.edges {
                    guard let a = nodeMap[e.from], let b = nodeMap[e.to] else { continue }
                    var path = Path()
                    path.move(to: a.position.applying(transform))
                    path.addLine(to: b.position.applying(transform))
                    let intensity = min(0.08 + Double(e.weight) * 0.06, 0.6)
                    let thickness = min(1.0 + CGFloat(e.weight) * 0.4, 4.0)
                    ctx.stroke(path, with: .color(.white.opacity(intensity)), lineWidth: thickness)
                }

                for n in vm.nodes {
                    let p = n.position.applying(transform)
                    let isSel = n.id == selectedID
                    let radius: CGFloat = 4 + CGFloat(min(n.count, 10)) * 0.6 + (isSel ? 3 : 0)
                    let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(n.color.opacity(isSel ? 1.0 : 0.85)))
                    if isSel {
                        let glowR = radius + 4
                        let glowRect = CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2)
                        ctx.stroke(Path(ellipseIn: glowRect), with: .color(n.color.opacity(0.4)), lineWidth: 2)
                    }
                    let label = Text(n.label)
                        .font(.system(size: isSel ? 11 : 9, weight: isSel ? .bold : .medium))
                        .foregroundColor(isSel ? .white : .white.opacity(0.7))
                    ctx.draw(ctx.resolve(label), at: CGPoint(x: p.x, y: p.y + radius + 10), anchor: .top)
                }
            }
            .gesture(MagnificationGesture().onChanged { v in
                scale = max(0.3, min(3.0, v * 0.5))
            })
            .simultaneousGesture(DragGesture().onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }.onEnded { _ in lastOffset = offset })
            .onTapGesture { loc in
                let t = CGAffineTransform(translationX: canvasCenter.x + offset.width,
                                          y: canvasCenter.y + offset.height)
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: -400, y: -400)
                var closest: (AuraNode, CGFloat)?
                for n in vm.nodes {
                    let p = n.position.applying(t)
                    let d = hypot(loc.x - p.x, loc.y - p.y)
                    if d < 30, closest == nil || d < closest!.1 { closest = (n, d) }
                }
                if let (node, _) = closest {
                    selectedID = node.id
                    navPath.append(node.label)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Your aura awakens as you chat")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
