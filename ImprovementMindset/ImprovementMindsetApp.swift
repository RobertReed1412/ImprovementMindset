import SwiftUI
import SwiftData

@main
struct ImprovementMindsetApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: TaskItem.self, PlayerProfile.self,
                CalorieDay.self, WorkoutEntry.self,
                ShelfItem.self,
                Circle.self, CircleCard.self,
                Strike.self, RulesConfig.self,
                Goal.self, GoalMove.self,
                CalendarEvent.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        configureAppearance()
    }

    private func configureAppearance() {
        let gold = UIColor(Theme.Palette.gold)
        let night = UIColor(Theme.Palette.nightDeep)
        let bone = UIColor(Theme.Palette.bone)

        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = night
        tab.stackedLayoutAppearance.selected.iconColor = gold
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: gold]
        tab.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.Palette.boneDim)
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.Palette.boneDim)]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Nav bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = night
        nav.titleTextAttributes = [.foregroundColor: bone]
        nav.largeTitleTextAttributes = [
            .foregroundColor: gold,
            .font: UIFont(name: "DragonKnight", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            mainTabs

            if showLaunch {
                LaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DailyMaintenance.run(context: context)
            Task { await LocalXPService.shared.ensureLoaded() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.5)) { showLaunch = false }
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "crown") }

            TasksView(kind: .daily, navTitle: "Daily")
                .tabItem { Label("Daily", systemImage: "sun.max") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.Palette.gold)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { DailyMaintenance.run(context: context) }
        }
    }
}
