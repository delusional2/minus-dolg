import SwiftUI
import SwiftData
import UIKit

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var mode = 0
    @State private var text = ""
    @State private var items: [ParsedSMS] = []
    @State private var dupKeys: Set<String> = []
    @State private var info = ""

    @State private var amount = ""
    @State private var name = ""
    @State private var manualCat: Cat = .food

    private var newCount: Int { items.filter { !dupKeys.contains($0.key) }.count }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Способ", selection: $mode) {
                    Text("Из SMS").tag(0)
                    Text("Вручную").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if mode == 0 { smsSection } else { manualSection }
            }
            .navigationTitle("Добавить траты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
        }
    }

    // MARK: Из SMS

    @ViewBuilder private var smsSection: some View {
        Section {
            TextEditor(text: $text)
                .frame(minHeight: 110)
                .onChange(of: text) { reparse() }
            Button {
                if let s = UIPasteboard.general.string { text = s }
            } label: {
                Label("Вставить из буфера", systemImage: "doc.on.clipboard")
            }
        } header: {
            Text("Текст SMS от 900")
        } footer: {
            Text("Можно вставить сразу несколько SMS. Тип можно дописать прямо в текст: #девушка, #еда, #такси, #связь, #долг, #другое. Коды подтверждения пропускаются.")
        }

        if !items.isEmpty {
            Section("Найдено: \(items.count)") {
                Menu {
                    ForEach(Cat.spendable) { c in
                        Button(c.rawValue) { for i in items.indices { items[i].cat = c } }
                    }
                } label: {
                    Label("Тип для всех", systemImage: "square.stack.3d.down.right")
                }
                ForEach($items) { $it in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(it.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(rub(it.amount)).monospacedDigit()
                        }
                        if dupKeys.contains(it.key) {
                            Text("Уже записано, второй раз не добавится").font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("Тип", selection: $it.cat) {
                            ForEach(Cat.allCases) { c in
                                Label(c.rawValue, systemImage: c.symbol).tag(c)
                            }
                        }
                    }
                }
            }
            Section {
                Button("Сохранить \(newCount)") { saveSMS() }
                    .disabled(newCount == 0)
            }
        }
        if !info.isEmpty {
            Section { Text(info).foregroundStyle(.secondary) }
        }
    }

    private func reparse() {
        var found: [ParsedSMS] = []
        var codes = 0, other = 0
        for chunk in SMSParser.split(text) {
            switch SMSParser.parse(chunk) {
            case .tx(let p):
                if !found.contains(where: { $0.key == p.key }) { found.append(p) }
            case .code: codes += 1
            case .notPurchase: other += 1
            }
        }
        // сохраняем уже выбранные вручную типы
        let chosen = Dictionary(items.map { ($0.key, $0.cat) }, uniquingKeysWith: { a, _ in a })
        for i in found.indices { if let c = chosen[found[i].key] { found[i].cat = c } }
        items = found
        dupKeys = Set(found.filter { Store.exists($0.key) }.map(\.key))
        var parts: [String] = []
        if codes > 0 { parts.append("коды пропущены: \(codes)") }
        if found.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.insert("Не нашёл покупок. Проверь, что это SMS о списании.", at: 0)
        }
        info = parts.joined(separator: ", ")
    }

    private func saveSMS() {
        for it in items where !dupKeys.contains(it.key) {
            ctx.insert(Tx(key: it.key, amount: it.amount, name: it.name, cat: it.cat, date: it.date, fromSMS: true))
        }
        try? ctx.save()
        dismiss()
    }

    // MARK: Вручную

    @ViewBuilder private var manualSection: some View {
        Section {
            TextField("Сумма, ₽", text: $amount).keyboardType(.decimalPad)
            TextField("Где или на что", text: $name)
            Picker("Тип", selection: $manualCat) {
                ForEach(Cat.allCases) { c in
                    Label(c.rawValue, systemImage: c.symbol).tag(c)
                }
            }
        }
        Section {
            Button("Добавить") { saveManual() }
                .disabled(parsedAmount <= 0)
        }
    }

    private var parsedAmount: Double {
        Double(amount.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func saveManual() {
        let n = name.trimmingCharacters(in: .whitespaces)
        ctx.insert(Tx(amount: parsedAmount, name: n.isEmpty ? manualCat.rawValue : n, cat: manualCat))
        try? ctx.save()
        dismiss()
    }
}
