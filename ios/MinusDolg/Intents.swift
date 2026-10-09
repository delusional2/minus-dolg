import AppIntents

/// Действие для приложения «Команды»: автоматизация «Сообщение от 900» передаёт сюда текст SMS.
struct AddSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Записать SMS от 900"
    static var description = IntentDescription("Разбирает SMS о покупке, записывает трату и говорит, сколько ещё можно потратить сегодня.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Текст SMS")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Записать трату из \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = Ledger.addFromSMS(text)
        if !outcome.added.isEmpty {
            Notifier.post(outcome.message)
        }
        return .result(dialog: "\(outcome.message)")
    }
}

struct MinusDolgShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddSMSIntent(),
            phrases: ["Записать трату в \(.applicationName)"],
            shortTitle: "Записать SMS",
            systemImageName: "text.bubble"
        )
    }
}
