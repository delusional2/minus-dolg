import Foundation
import SwiftData

// MARK: - Категории трат

enum Cat: String, CaseIterable, Identifiable, Codable {
    case food = "Еда вне дома"
    case girl = "Девушка"
    case taxi = "Такси"
    case phone = "Связь"
    case transport = "Транспорт"
    case market = "Маркетплейсы"
    case subs = "Подписки"
    case groceries = "Продукты"
    case transfers = "Переводы"
    case other = "Другое"
    case debt = "Долг"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .girl: return "heart.fill"
        case .taxi: return "car.fill"
        case .phone: return "antenna.radiowaves.left.and.right"
        case .transport: return "tram.fill"
        case .market: return "shippingbox.fill"
        case .subs: return "play.rectangle.fill"
        case .groceries: return "cart.fill"
        case .transfers: return "arrow.left.arrow.right"
        case .other: return "square.grid.2x2.fill"
        case .debt: return "arrow.down.to.line"
        }
    }

    static var spendable: [Cat] { allCases.filter { $0 != .debt } }
}

// MARK: - Трата

@Model
final class Tx {
    @Attribute(.unique) var key: String
    var amount: Double
    var name: String
    var catRaw: String
    var date: Date
    var fromSMS: Bool

    init(key: String = UUID().uuidString, amount: Double, name: String, cat: Cat, date: Date = .now, fromSMS: Bool = false) {
        self.key = key
        self.amount = amount
        self.name = name
        self.catRaw = cat.rawValue
        self.date = date
        self.fromSMS = fromSMS
    }

    var cat: Cat { Cat(rawValue: catRaw) ?? .other }
}

// MARK: - Хранилище

@MainActor
enum Store {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Tx.self)
        } catch {
            fatalError("Не удалось открыть базу: \(error)")
        }
    }()

    static var context: ModelContext { container.mainContext }

    static func all() -> [Tx] {
        let d = FetchDescriptor<Tx>(sortBy: [SortDescriptor(\Tx.date, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    static func exists(_ key: String) -> Bool {
        var d = FetchDescriptor<Tx>(predicate: #Predicate<Tx> { $0.key == key })
        d.fetchLimit = 1
        return ((try? context.fetchCount(d)) ?? 0) > 0
    }
}

// MARK: - План (настройки)

struct Plan {
    var income: Double
    var debtTotal: Double
    var debtMonthly: Double
    var girlMonth: Double
    var foodWeek: Double
    var taxiWeek: Double
    var fixedMonth: Double

    enum Key {
        static let income = "income"
        static let debtTotal = "debtTotal"
        static let debtMonthly = "debtMonthly"
        static let girlMonth = "girlMonth"
        static let foodWeek = "foodWeek"
        static let taxiWeek = "taxiWeek"
        static let fixedMonth = "fixedMonth"
    }

    static let defaults: [String: Any] = [
        Key.income: 117000.0,
        Key.debtTotal: 500000.0,
        Key.debtMonthly: 60000.0,
        Key.girlMonth: 25000.0,
        Key.foodWeek: 2700.0,
        Key.taxiWeek: 0.0,
        Key.fixedMonth: 4000.0,
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }

    static func load() -> Plan {
        let d = UserDefaults.standard
        registerDefaults()
        return Plan(
            income: d.double(forKey: Key.income),
            debtTotal: d.double(forKey: Key.debtTotal),
            debtMonthly: d.double(forKey: Key.debtMonthly),
            girlMonth: d.double(forKey: Key.girlMonth),
            foodWeek: d.double(forKey: Key.foodWeek),
            taxiWeek: d.double(forKey: Key.taxiWeek),
            fixedMonth: d.double(forKey: Key.fixedMonth)
        )
    }
}

// MARK: - Форматирование

private let rubFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "ru_RU")
    f.maximumFractionDigits = 0
    return f
}()

func rub(_ v: Double) -> String {
    (rubFormatter.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))") + " ₽"
}

func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10, n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}
