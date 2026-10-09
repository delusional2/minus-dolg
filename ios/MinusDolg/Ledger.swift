import Foundation
import SwiftData
import UserNotifications

/// Запись трат из SMS и короткий фидбек после каждой.
@MainActor
enum Ledger {
    struct Outcome {
        let added: [Tx]
        let message: String
    }

    static func addFromSMS(_ text: String) -> Outcome {
        var added: [Tx] = []
        var codes = 0
        for chunk in SMSParser.split(text) {
            switch SMSParser.parse(chunk) {
            case .code:
                codes += 1
            case .notPurchase:
                continue
            case .tx(let p):
                if Store.exists(p.key) || added.contains(where: { $0.key == p.key }) { continue }
                let t = Tx(key: p.key, amount: p.amount, name: p.name, cat: p.cat, date: p.date, fromSMS: true)
                Store.context.insert(t)
                added.append(t)
            }
        }
        try? Store.context.save()

        if added.isEmpty {
            let msg = codes > 0 ? "Это код подтверждения, пропустил." : "В сообщении нет покупки, ничего не записал."
            return Outcome(added: [], message: msg)
        }
        return Outcome(added: added, message: feedback(for: added))
    }

    static func feedback(for added: [Tx]) -> String {
        let plan = Plan.load()
        let b = Budget(plan: plan, txs: Store.all(), now: .now)
        var parts = added.prefix(3).map { line(for: $0, b: b, plan: plan) }
        if added.count > 3 { parts.append("И ещё \(added.count - 3).") }
        if plan.income > 0 {
            parts.append(b.todayLeft >= 0
                ? "Сегодня можно ещё \(rub(b.todayLeft))."
                : "Сегодня уже перебор на \(rub(-b.todayLeft)).")
        }
        return parts.joined(separator: " ")
    }

    private static func line(for t: Tx, b: Budget, plan: Plan) -> String {
        let a = rub(t.amount)
        switch t.cat {
        case .taxi:
            if plan.taxiWeek == 0 { return "Такси −\(a). Договорились без такси, эти деньги могли уйти в долг." }
            let left = plan.taxiWeek - b.week(.taxi)
            return left >= 0 ? "Такси −\(a). На неделю осталось \(rub(left))." : "Такси −\(a). Перебор за неделю \(rub(-left))."
        case .food:
            let left = plan.foodWeek - b.week(.food)
            return left >= 0 ? "Еда −\(a). На неделю осталось \(rub(left))." : "Еда −\(a). Перебор за неделю \(rub(-left))."
        case .girl:
            return "Девушка −\(a). За месяц \(rub(b.month(.girl))) из \(rub(plan.girlMonth))."
        case .debt:
            return "Долг: отдано \(a). Осталось \(rub(b.debtLeft))."
        default:
            return "\(t.cat.rawValue) −\(a), \(t.name)."
        }
    }
}

enum Notifier {
    static func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func post(_ body: String) {
        let c = UNMutableNotificationContent()
        c.title = "Минус долг"
        c.body = body
        c.sound = .default
        let r = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(r)
    }
}
