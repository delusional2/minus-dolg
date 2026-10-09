import Foundation

struct ParsedSMS: Identifiable {
    let key: String
    let amount: Double
    let name: String
    var cat: Cat
    let tagged: Bool
    let date: Date
    var id: String { key }
}

enum ParseResult {
    case tx(ParsedSMS)
    case code
    case notPurchase
}

/// Разбор SMS от 900 (СберБанк).
/// Примеры: «MIR-1234 14:32 Покупка 450р YANDEX*TAXI Баланс: 12 345,67р»
///          «VISA5678 09.10.26 08:15 Оплата 1 250,50р DODO PIZZA Баланс: 3 000р»
enum SMSParser {
    private static let op = try! NSRegularExpression(
        pattern: #"(Покупка|Оплата|Списание|Перевод|Выдача наличных|Выдача)\s*(?:на сумму\s*)?(?:для\s+[^\d]*?)?(\d[\d\s ]*(?:[.,]\d{1,2})?)\s*(?:р\.?|₽|руб\.?|RUB)"#,
        options: [.caseInsensitive]
    )

    private static let rules: [(Cat, String)] = [
        (.taxi, #"TAXI|ТАКСИ|UBER|CITYMOBIL|СИТИМОБИЛ|MAXIM|МАКСИМ|YANDEX\W?GO|ЯНДЕКС\W?GO|DIDI|WHEELY|INDRIVE"#),
        (.food, #"YANDEX\W?EDA|ЯНДЕКС\W?ЕДА|EDA\.YANDEX|DELIVERY|ДОСТАВКА|SAMOKAT|САМОКАТ|LAVKA|ЛАВКА|KFC|ROSTIC|VKUSNO|ВКУСНО|BURGER|БУРГЕР|MCDON|COFFEE|КОФЕ|KOFE|CAFE|КАФЕ|РЕСТОРАН|RESTORAN|SUSHI|СУШИ|PIZZA|ПИЦЦ|DODO|ДОДО|TEREMOK|ТЕРЕМОК|SHOKOLADN|STARBUCKS|COFIX|SHAURM|ШАУРМ|DONER|KITCHEN|GRILL|TANUKI|STOLOVAYA|СТОЛОВАЯ|SURF"#),
        (.phone, #"\bMTS\b|МТС|BEELINE|БИЛАЙН|MEGAFON|МЕГАФОН|TELE2|ТЕЛЕ2|\bT2\b|YOTA|ЙОТА|ROSTELECOM|РОСТЕЛЕКОМ"#),
        (.groceries, #"PYATEROCHKA|ПЯТЕРОЧКА|ПЯТЁРОЧКА|MAGNIT|МАГНИТ|PEREKRESTOK|ПЕРЕКРЕСТОК|VKUSVILL|ВКУСВИЛЛ|AUCHAN|АШАН|LENTA|ЛЕНТА|DIXY|ДИКСИ|SPAR|GLOBUS|ГЛОБУС|AZBUKA|АЗБУКА|BILLA|FIX PRICE|SVETOFOR|СВЕТОФОР"#),
        (.market, #"OZON|ОЗОН|WILDBERRIES|ВАЙЛДБЕРРИЗ|\bWB\b|YANDEX\W?MARKET|ЯНДЕКС\W?МАРКЕТ|ALIEXPRESS|LAMODA|MEGAMARKET|AVITO|АВИТО"#),
        (.transport, #"METRO|МЕТРО|TROIKA|ТРОЙКА|MOSGORTRANS|МОСГОРТРАНС|TRANSPORT|ТРАНСПОРТ|RZD|РЖД|AEROEXPRESS|WHOOSH|URENT|ЮРЕНТ|PODOROZHNIK|АЗС|LUKOIL|ЛУКОЙЛ"#),
        (.subs, #"YANDEX\W?PLUS|ПЛЮС|KINOPOISK|КИНОПОИСК|SPOTIFY|APPLE\.COM|ITUNES|VK MUSIC|BOOM|IVI|OKKO|WINK|PREMIER|YOUTUBE|NETFLIX|SBERPRIME|СБЕРПРАЙМ|TELEGRAM"#),
    ]

    /// Метки, которые можно дописать в текст: #девушка, #еда …
    private static let tags: [(String, Cat)] = [
        ("девушка", .girl), ("дев", .girl), ("еда", .food), ("обед", .food), ("кафе", .food),
        ("такси", .taxi), ("связь", .phone), ("телефон", .phone), ("транспорт", .transport),
        ("метро", .transport), ("маркет", .market), ("подписка", .subs), ("продукты", .groceries),
        ("перевод", .transfers), ("другое", .other), ("долг", .debt),
    ]

    private static func has(_ pattern: String, _ s: String) -> Bool {
        s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func autoCat(name: String, operation: String) -> Cat {
        if has("Перевод", operation) { return .transfers }
        for (cat, pattern) in rules where has(pattern, name) { return cat }
        return .other
    }

    private static func tagCat(_ s: String) -> Cat? {
        guard let r = s.range(of: #"#[а-яёa-z]+"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let word = s[r].dropFirst().lowercased()
        for (key, cat) in tags where word.hasPrefix(key) { return cat }
        return nil
    }

    /// Делит вставленный текст на отдельные SMS.
    static func split(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var chunks: [String] = []
        for line in lines {
            guard let last = chunks.last else { chunks.append(line); continue }
            let onlyTag = has(#"^#[а-яёa-z]+$"#, line)
            let lastHasOp = op.firstMatch(in: last, range: NSRange(last.startIndex..., in: last)) != nil
            let glue = onlyTag || (!lastHasOp && !has("Код|Никому|пароль", last + line))
            if glue { chunks[chunks.count - 1] += " " + line } else { chunks.append(line) }
        }
        return chunks
    }

    static func parse(_ raw: String, now: Date = .now) -> ParseResult {
        if has("Никому не сообщайте|код подтверждения|Код:|пароль", raw) { return .code }

        let clean = raw
            .replacingOccurrences(of: #"#[а-яёa-z]+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let ns = clean as NSString
        guard let m = op.firstMatch(in: clean, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3,
              m.range(at: 1).location != NSNotFound,
              m.range(at: 2).location != NSNotFound
        else { return .notPurchase }

        let operation = ns.substring(with: m.range(at: 1))
        let amountText = ns.substring(with: m.range(at: 2))
            .replacingOccurrences(of: #"[\s ]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountText), amount > 0 else { return .notPurchase }

        var after = ns.substring(from: m.range.location + m.range.length)
        if let r = after.range(of: "Баланс|Остаток|Доступно", options: [.regularExpression, .caseInsensitive]) {
            after = String(after[..<r.lowerBound])
        }
        after = after.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-"))
        let name = String((after.isEmpty ? operation : after).prefix(60))

        let tag = tagCat(raw)
        return .tx(ParsedSMS(
            key: hash(clean),
            amount: amount,
            name: name,
            cat: tag ?? autoCat(name: name, operation: operation),
            tagged: tag != nil,
            date: date(in: clean, now: now)
        ))
    }

    private static func date(in s: String, now: Date) -> Date {
        let cal = Calendar.current
        let ns = s as NSString
        let full = try! NSRegularExpression(pattern: #"(\d{2})\.(\d{2})(?:\.(\d{2,4}))?\s+(\d{1,2}):(\d{2})"#)
        if let m = full.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) {
            func g(_ i: Int) -> Int? {
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : Int(ns.substring(with: r))
            }
            var y = g(3) ?? cal.component(.year, from: now)
            if y < 100 { y += 2000 }
            var c = DateComponents()
            c.year = y; c.month = g(2); c.day = g(1); c.hour = g(4); c.minute = g(5)
            if let d = cal.date(from: c) { return d }
        }
        let time = try! NSRegularExpression(pattern: #"(?:^|\s)(\d{1,2}):(\d{2})(?:\s|$)"#)
        if let m = time.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
           let h = Int(ns.substring(with: m.range(at: 1))),
           let mi = Int(ns.substring(with: m.range(at: 2))),
           var d = cal.date(bySettingHour: h, minute: mi, second: 0, of: now) {
            if d > now { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
            return d
        }
        return now
    }

    private static func hash(_ s: String) -> String {
        var h: UInt32 = 5381
        for u in s.unicodeScalars { h = (h &<< 5) &+ h &+ u.value }
        return "s" + String(h, radix: 36)
    }
}
