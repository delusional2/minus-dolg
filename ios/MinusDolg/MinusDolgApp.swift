import SwiftUI
import SwiftData

@main
struct MinusDolgApp: App {
    init() {
        Plan.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { await Notifier.request() }
        }
        .modelContainer(Store.container)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Главная", systemImage: "gauge.with.dots.needle.33percent") }
            HistoryView()
                .tabItem { Label("История", systemImage: "list.bullet") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }
        }
    }
}

// MARK: - Общие элементы

extension Level {
    var color: Color {
        switch self {
        case .ok: return .green
        case .warn: return .orange
        case .bad: return .red
        case .info: return .secondary
        }
    }
}

struct Card<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Meter: View {
    let value: Double
    let total: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(tint)
                    .frame(width: geo.size.width * CGFloat(total > 0 ? min(1, max(0, value / total)) : (value > 0 ? 1 : 0)))
            }
        }
        .frame(height: 8)
    }
}
