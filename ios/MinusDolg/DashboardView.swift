import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]

    @AppStorage(Plan.Key.income) private var income = 117000.0
    @AppStorage(Plan.Key.debtTotal) private var debtTotal = 500000.0
    @AppStorage(Plan.Key.debtMonthly) private var debtMonthly = 60000.0
    @AppStorage(Plan.Key.girlMonth) private var girlMonth = 25000.0
    @AppStorage(Plan.Key.foodWeek) private var foodWeek = 2700.0
    @AppStorage(Plan.Key.taxiWeek) private var taxiWeek = 0.0
    @AppStorage(Plan.Key.fixedMonth) private var fixedMonth = 4000.0

    @State private var showAdd = false
    @State private var showPay = false
    @State private var payText = ""

    private var plan: Plan {
        Plan(income: income, debtTotal: debtTotal, debtMonthly: debtMonthly, girlMonth: girlMonth,
             foodWeek: foodWeek, taxiWeek: taxiWeek, fixedMonth: fixedMonth)
    }

    var body: some View {
        let b = Budget(plan: plan, txs: txs, now: .now)
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if txs.isEmpty { onboarding }
                    today(b)
                    limits(b)
                    debt(b)
                    forecast(b)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Минус долг")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        .accessibilityLabel("Добавить траты")
                }
            }
            .sheet(isPresented: $showAdd) { AddView() }
            .alert("Отдал часть долга", isPresented: $showPay) {
                TextField("Сумма, ₽", text: $payText).keyboardType(.numberPad)
                Button("Записать") { recordPayment() }
                Button("Отмена", role: .cancel) { payText = "" }
            } message: {
                Text("Сколько отдал?")
            }
        }
    }

    // MARK: Блоки

    private var onboarding: some View {
        Card("С чего начать") {
            Text("1. Проверь цифры во вкладке «Настройки».\n2. Там же настрой автозапись SMS от 900, это 2 минуты.\n3. Или нажми «+» вверху и вставь SMS вручную.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func today(_ b: Budget) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("МОЖНО СЕГОДНЯ").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text(rub(max(0, b.todayLeft)))
                        .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(b.todayLeft < 0 ? .red : .primary)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(b.todayLeft < 0 ? "перебор \(rub(-b.todayLeft))" : "потрачено \(rub(b.spentToday)) из \(rub(max(0, b.perDayToday)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ОСТАЛОСЬ НА МЕСЯЦ").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text(rub(max(0, b.monthLeft)))
                        .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(b.monthLeft < 0 ? .red : .primary)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("из \(rub(b.spendBudget)) · ещё \(b.daysLeft) дн.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Meter(value: b.spentMonth, total: b.spendBudget)
        }
    }

    private func limits(_ b: Budget) -> some View {
        Card("Лимиты") {
            limitRow("Еда вне дома", spent: b.week(.food), limit: plan.foodWeek, period: "на неделю")
            limitRow("Такси", spent: b.week(.taxi), limit: plan.taxiWeek, period: "на неделю")
            limitRow("Девушка", spent: b.month(.girl), limit: plan.girlMonth, period: "на месяц")
            limitRow("Связь и транспорт", spent: b.month(.phone) + b.month(.transport), limit: plan.fixedMonth, period: "на месяц")
        }
    }

    private func limitRow(_ name: String, spent: Double, limit: Double, period: String) -> some View {
        let level: Level
        let note: String
        if limit <= 0 {
            level = spent > 0 ? .bad : .ok
            note = spent > 0 ? "договорились без него, это срыв" : "ноль, так и держи"
        } else {
            let p = spent / limit
            level = p > 1 ? .bad : (p > 0.8 ? .warn : .ok)
            note = p > 1 ? "перебор \(rub(spent - limit)) \(period)" : "осталось \(rub(limit - spent)) \(period)"
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline.weight(.medium))
                Spacer()
                Text(limit > 0 ? "\(rub(spent)) / \(rub(limit))" : rub(spent))
                    .font(.subheadline).monospacedDigit()
            }
            Meter(value: spent, total: limit, tint: level.color)
            Text(note).font(.caption).foregroundStyle(level == .ok ? Color.secondary : level.color)
        }
    }

    private func debt(_ b: Budget) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Долг").font(.headline)
                Spacer()
                Text(plan.debtTotal > 0 ? (b.debtLeft > 0 ? rub(b.debtLeft) : "закрыт") : "—")
                    .font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            Meter(value: b.paidTotal, total: plan.debtTotal)
            Text(debtNote(b)).font(.caption).foregroundStyle(.secondary)
            Button { showPay = true } label: {
                Label("Отдал часть долга", systemImage: "arrow.down.to.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func debtNote(_ b: Budget) -> String {
        guard plan.debtTotal > 0 else { return "Впиши сумму долга в настройках." }
        if b.debtLeft == 0 { return "Долг закрыт. Теперь эти деньги можно откладывать себе." }
        var s = "Отдано \(rub(b.paidTotal)) из \(rub(plan.debtTotal))."
        if let d = b.payoffDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateFormat = "LLLL yyyy"
            s += " Закроешь к: \(f.string(from: d))."
        }
        if plan.debtMonthly > 0 {
            s += b.paidMonth >= plan.debtMonthly ? " План месяца выполнен." : " В этом месяце ещё \(rub(plan.debtMonthly - b.paidMonth))."
        }
        return s
    }

    private func forecast(_ b: Budget) -> some View {
        Card("Прогноз") {
            ForEach(Array(b.forecast.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(item.0.color).frame(width: 7, height: 7)
                    Text(item.1).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func recordPayment() {
        let v = Double(payText.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
        payText = ""
        guard v > 0 else { return }
        ctx.insert(Tx(amount: v, name: "Возврат долга", cat: .debt))
        try? ctx.save()
    }
}
