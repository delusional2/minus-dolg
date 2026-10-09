import Foundation

enum Level { case ok, warn, bad, info }

/// Все расчёты: сколько можно сегодня, лимиты, долг, прогноз.
struct Budget {
    let plan: Plan
    let txs: [Tx]
    let now: Date

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.firstWeekday = 2
        return c
    }

    var dayStart: Date { cal.startOfDay(for: now) }
    var weekStart: Date { cal.dateInterval(of: .weekOfYear, for: now)?.start ?? dayStart }
    var weekEnd: Date { cal.date(byAdding: .day, value: 6, to: weekStart) ?? now }
    var monthStart: Date { cal.dateInterval(of: .month, for: now)?.start ?? dayStart }
    var daysInMonth: Int { cal.range(of: .day, in: .month, for: now)?.count ?? 30 }
    var dayOfMonth: Int { cal.component(.day, from: now) }
    var daysLeft: Int { daysInMonth - dayOfMonth + 1 }
    var daysLeftInWeek: Int { 7 - ((cal.component(.weekday, from: now) + 5) % 7) }

    private func sum(_ f: (Tx) -> Bool) -> Double { txs.filter(f).reduce(0) { $0 + $1.amount } }

    // Сегодня и месяц
    var spendBudget: Double { plan.income - plan.debtMonthly }
    var spentMonth: Double { sum { $0.date >= monthStart && $0.cat != .debt } }
    var spentBeforeToday: Double { sum { $0.date >= monthStart && $0.date < dayStart && $0.cat != .debt } }
    var spentToday: Double { spentMonth - spentBeforeToday }
    var perDayToday: Double { (spendBudget - spentBeforeToday) / Double(max(1, daysLeft)) }
    var todayLeft: Double { perDayToday - spentToday }
    var monthLeft: Double { spendBudget - spentMonth }

    func week(_ c: Cat) -> Double { sum { $0.date >= weekStart && $0.cat == c } }
    func month(_ c: Cat) -> Double { sum { $0.date >= monthStart && $0.cat == c } }

    // Долг
    var paidTotal: Double { sum { $0.cat == .debt } }
    var paidMonth: Double { month(.debt) }
    var debtLeft: Double { max(0, plan.debtTotal - paidTotal) }
    var payoffDate: Date? {
        guard debtLeft > 0, plan.debtMonthly > 0 else { return nil }
        let n = Int((debtLeft / plan.debtMonthly).rounded(.up))
        return cal.date(byAdding: .month, value: n, to: monthStart)
    }

    // Прогноз
    var forecast: [(Level, String)] {
        var out: [(Level, String)] = []
        let spends = txs.filter { $0.cat != .debt }

        if plan.income > 0, let first = txs.map(\.date).min(), !spends.isEmpty {
            let from = max(monthStart, cal.startOfDay(for: first))
            let tracked = max(1, (cal.dateComponents([.day], from: from, to: dayStart).day ?? 0) + 1)
            if tracked < 3 {
                out.append((.info, "Прогноз на месяц появится через пару дней. Пока потрачено \(rub(spentMonth)) из \(rub(spendBudget))."))
            } else {
                let proj = spentMonth / Double(tracked) * Double(daysInMonth)
                let diff = spendBudget - proj
                if diff >= 0 {
                    out.append((.ok, "В таком темпе к концу месяца потратишь около \(rub(proj)) и останется \(rub(diff)). Их можно отдать в долг сверх плана."))
                } else {
                    out.append((.bad, "В таком темпе к концу месяца потратишь около \(rub(proj)), это на \(rub(-diff)) больше, чем можно. Притормози."))
                }
            }

            let norm = spendBudget / Double(daysInMonth)
            var streak = 0
            var d = cal.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
            while d >= from {
                let next = cal.date(byAdding: .day, value: 1, to: d) ?? d
                let daySum = sum { $0.cat != .debt && $0.date >= d && $0.date < next }
                if daySum <= norm { streak += 1 } else { break }
                d = cal.date(byAdding: .day, value: -1, to: d) ?? from.addingTimeInterval(-1)
            }
            if streak > 0 {
                out.append((.ok, "\(streak) \(plural(streak, "день", "дня", "дней")) подряд укладываешься в дневную норму \(rub(norm))."))
            } else if let y = cal.date(byAdding: .day, value: -1, to: dayStart), y >= from {
                out.append((.warn, "Вчера вышел за дневную норму \(rub(norm)). Сегодня хороший день, чтобы отыграть."))
            }
        } else if plan.income <= 0 {
            out.append((.info, "Впиши доход в настройках, чтобы появился прогноз."))
        }

        if plan.taxiWeek == 0, let first = txs.map(\.date).min() {
            let taxis = txs.filter { $0.cat == .taxi }
            let since = taxis.map(\.date).max() ?? first
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: since), to: dayStart).day ?? 0
            if taxis.isEmpty {
                out.append((.ok, "Без такси с начала учёта: \(days) \(plural(days, "день", "дня", "дней"))."))
            } else if days == 0 {
                out.append((.bad, "Сегодня было такси. Счётчик дней без такси начнётся заново."))
            } else {
                out.append((.ok, "\(days) \(plural(days, "день", "дня", "дней")) без такси."))
            }
        }

        if plan.debtTotal > 0, plan.debtMonthly > 0, debtLeft > 0, paidMonth < plan.debtMonthly {
            out.append((.info, "До плана по долгу в этом месяце: \(rub(plan.debtMonthly - paidMonth)). Отдай в день зарплаты, первым делом."))
        }

        if out.isEmpty {
            out.append((.info, "Прогноз появится, как только добавишь первые траты."))
        }
        return out
    }
}
