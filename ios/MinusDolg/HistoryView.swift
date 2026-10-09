import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]
    @State private var filter: Cat?
    @State private var showAdd = false

    private var shown: [Tx] {
        guard let filter else { return txs }
        return txs.filter { $0.cat == filter }
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                if shown.isEmpty {
                    Text(txs.isEmpty ? "Пока нет ни одной траты. Нажми «+», чтобы добавить." : "В этой категории пока пусто.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        HStack {
                            Text("Всего")
                            Spacer()
                            Text(rub(shown.filter { $0.cat != .debt }.reduce(0) { $0 + $1.amount })).monospacedDigit()
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    Section {
                        ForEach(shown) { t in row(t) }
                            .onDelete { idx in
                                let list = shown
                                for i in idx { ctx.delete(list[i]) }
                                try? ctx.save()
                            }
                    }
                }
            }
            .navigationTitle(filter?.rawValue ?? "История")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Все") { filter = nil }
                        ForEach(Cat.allCases) { c in
                            Button { filter = c } label: { Label(c.rawValue, systemImage: c.symbol) }
                        }
                    } label: {
                        Label("Фильтр", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        .accessibilityLabel("Добавить траты")
                }
            }
            .sheet(isPresented: $showAdd) { AddView() }
        }
    }

    private func row(_ t: Tx) -> some View {
        HStack(spacing: 12) {
            Image(systemName: t.cat.symbol)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: Circle())
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.name).font(.subheadline.weight(.medium)).lineLimit(2)
                HStack(spacing: 6) {
                    Text(Self.dateFmt.string(from: t.date))
                    Menu {
                        ForEach(Cat.allCases) { c in
                            Button { t.catRaw = c.rawValue; try? ctx.save() } label: { Label(c.rawValue, systemImage: c.symbol) }
                        }
                    } label: {
                        Text(t.cat.rawValue).underline()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text((t.cat == .debt ? "→ " : "−") + rub(t.amount))
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(t.cat == .debt ? Color.accentColor : .primary)
        }
    }
}
