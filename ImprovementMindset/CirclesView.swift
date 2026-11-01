import SwiftUI
import SwiftData

struct CirclesView: View {
    var body: some View { NavigationStack { CirclesContent() } }
}

struct CirclesContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Circle.createdAt, order: .reverse) private var circles: [Circle]
    @State private var showingAdd = false
    @State private var newLabel = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
            Group {
                if circles.isEmpty {
                    ContentUnavailableView(
                        "No circles yet",
                        systemImage: "circle.circle",
                        description: Text("Create a circle, then fill it with cards."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(circles) { circle in
                                NavigationLink(value: circle.id) {
                                    CircleBadge(circle: circle)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        context.delete(circle); try? context.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Circles")
            .nightBackground()
            .navigationDestination(for: UUID.self) { id in
                if let circle = circles.first(where: { $0.id == id }) {
                    CircleDeckView(circle: circle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .alert("New circle", isPresented: $showingAdd) {
                TextField("Label", text: $newLabel)
                Button("Cancel", role: .cancel) { newLabel = "" }
                Button("Create") { create() }
            } message: {
                Text("Name this circle (e.g. a question, theme, or topic).")
            }
    }

    private func create() {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        context.insert(Circle(label: label))
        newLabel = ""
        try? context.save()
    }
}

struct CircleBadge: View {
    let circle: Circle
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                SwiftUI.Circle()
                    .fill(RadialGradient(colors: [Theme.Palette.malachite.opacity(0.35), Theme.Palette.night],
                                         center: .center, startRadius: 4, endRadius: 70))
                    .frame(width: 130, height: 130)
                SwiftUI.Circle()
                    .stroke(Theme.goldStroke, lineWidth: 1.5)
                    .frame(width: 130, height: 130)
                SwiftUI.Circle()
                    .stroke(Theme.Palette.goldDim.opacity(0.6), lineWidth: 1)
                    .frame(width: 112, height: 112)
                VStack(spacing: 4) {
                    Text(circle.label)
                        .font(Theme.display(18, weight: .semibold))
                        .foregroundStyle(Theme.Palette.bone)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(width: 100)
                    Text("\(circle.cards.count) card\(circle.cards.count == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(Theme.Palette.boneDim)
                }
            }
        }
    }
}

struct CircleDeckView: View {
    @Bindable var circle: Circle
    @Environment(\.modelContext) private var context
    @State private var selection: Int = 0

    private var cards: [CircleCard] {
        circle.cards.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No cards",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Tap + to add the first card to this circle."))
            } else {
                TabView(selection: $selection) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                        CardEditor(card: card)
                            .padding()
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text("Card \(min(selection + 1, cards.count)) of \(cards.count)")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(circle.label)
        .navigationBarTitleDisplayMode(.inline)
        .nightBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addCard() } label: { Image(systemName: "plus") }
            }
            if !cards.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { deleteCurrent() } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func addCard() {
        let nextOrder = (cards.last?.order ?? -1) + 1
        let card = CircleCard(order: nextOrder)
        card.circle = circle
        circle.cards.append(card)
        context.insert(card)
        try? context.save()
        selection = cards.count - 1
    }

    private func deleteCurrent() {
        guard cards.indices.contains(selection) else { return }
        let card = cards[selection]
        context.delete(card)
        try? context.save()
        selection = max(0, selection - 1)
    }
}

struct CardEditor: View {
    @Bindable var card: CircleCard
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $card.title)
                .font(Theme.display(24, weight: .bold))
                .foregroundStyle(Theme.Palette.parchmentInk)
                .onChange(of: card.title) { _, _ in try? context.save() }

            Rectangle().fill(Theme.Palette.goldDim.opacity(0.5)).frame(height: 1)

            TextField("Write this card's contents…",
                      text: $card.body, axis: .vertical)
                .foregroundStyle(Theme.Palette.parchmentInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onChange(of: card.body) { _, _ in try? context.save() }

            Spacer()
        }
        .padding(22)
        .parchmentSurface(cornerRadius: 18)
    }
}
