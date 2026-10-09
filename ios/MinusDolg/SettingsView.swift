import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx

    @AppStorage(Plan.Key.income) private var income = 117000.0
    @AppStorage(Plan.Key.debtTotal) private var debtTotal = 500000.0
    @AppStorage(Plan.Key.debtMonthly) private var debtMonthly = 60000.0
    @AppStorage(Plan.Key.girlMonth) private var girlMonth = 25000.0
    @AppStorage(Plan.Key.foodWeek) private var foodWeek = 2700.0
    @AppStorage(Plan.Key.taxiWeek) private var taxiWeek = 0.0
    @AppStorage(Plan.Key.fixedMonth) private var fixedMonth = 4000.0

    @State private var confirmReset = false
    @State private var testResult = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    money("Доход в месяц", $income)
                    money("На долг в месяц", $debtMonthly)
                    money("Весь долг", $debtTotal)
                } header: {
                    Text("Доход и долг")
                } footer: {
                    Text("На жизнь остаётся \(rub(income - debtMonthly)) в месяц, в среднем \(rub((income - debtMonthly) / 30)) в день.")
                }

                Section("Лимиты") {
                    money("Девушка в месяц", $girlMonth)
                    money("Еда вне дома в неделю", $foodWeek)
                    money("Такси в неделю", $taxiWeek)
                    money("Связь и соцкарта в месяц", $fixedMonth)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        step(1, "Открой приложение «Команды» → вкладка «Автоматизация» → «+».")
                        step(2, "Выбери «Сообщение». В «Отправитель» укажи 900 (если нет в контактах, сохрани номер 900 как «СберБанк»). В «Сообщение содержит» впиши: Покупка")
                        step(3, "Отметь «Запускать сразу» и нажми «Далее» → «Новая пустая автоматизация».")
                        step(4, "Добавь действие «Записать SMS от 900» (приложение «Минус долг»).")
                        step(5, "Нажми на поле «Текст SMS» и выбери переменную «Ввод быстрой команды». Готово.")
                    }
                    .font(.subheadline)
                } header: {
                    Text("Автозапись SMS от 900")
                } footer: {
                    Text("После этого каждая покупка по карте запишется сама, а ты получишь уведомление: сколько потратил и сколько ещё можно сегодня. Сделай вторую такую же автоматизацию со словом «Оплата», если Сбер присылает и такие SMS.")
                }

                Section {
                    Button("Проверить на примере SMS") {
                        let r = Ledger.addFromSMS("MIR-0000 Покупка 1р ПРОВЕРКА \(UUID().uuidString.prefix(4)) Баланс: 0р")
                        testResult = r.added.isEmpty ? r.message : "Работает: \(r.message) Запись «ПРОВЕРКА» на 1 ₽ можно удалить в «Истории» свайпом."
                    }
                    if !testResult.isEmpty {
                        Text(testResult).font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Разрешить уведомления") {
                        Task { await Notifier.request() }
                    }
                }

                Section {
                    Button("Удалить все траты и начать с нуля", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Настройки останутся. Удалённое вернуть нельзя.")
                }
            }
            .navigationTitle("Настройки")
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("Удалить все траты и платежи по долгу?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Удалить всё", role: .destructive) {
                    try? ctx.delete(model: Tx.self)
                    try? ctx.save()
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private func money(_ title: String, _ value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 120)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
