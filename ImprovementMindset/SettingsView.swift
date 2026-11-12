import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    private var xp: LocalXPService { LocalXPService.shared }
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var reminderStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingReminders = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Home page") {
                    NavigationLink {
                        EditHomeView()
                    } label: {
                        Label("Edit home page", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("settings.editHome")
                }

                remindersSection

                Section("On-device XP model") {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("Qwen2.5-1.5B (4-bit)")
                            .foregroundStyle(.secondary)
                    }
                    statusRow
                }

                Section {
                    switch xp.state {
                    case .ready:
                        Label("Model ready — XP is scored fully on-device.",
                              systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    case .idle, .failed:
                        Button {
                            Task { await xp.ensureLoaded() }
                        } label: {
                            Label("Download model now", systemImage: "arrow.down.circle")
                        }
                    default:
                        EmptyView()
                    }
                }

                Section {
                    Text("""
                    The XP model runs entirely on your phone using Apple's MLX \
                    framework. It downloads once (~0.9 GB) on first use, then works \
                    offline. Until it's ready, XP uses a built-in scoring formula.
                    """)
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .nightBackground()
            .task { await refreshReminders() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshReminders() } }
            }
        }
    }

    // MARK: Event reminders (local notifications)

    private var statusText: String {
        switch reminderStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Off"
        case .notDetermined: return "Not set up"
        @unknown default: return "Unknown"
        }
    }

    private var remindersSection: some View {
        Section {
            HStack {
                Text("Notifications")
                Spacer()
                Text(statusText).foregroundStyle(.secondary)
                    .accessibilityIdentifier("reminders.status")
            }
            switch reminderStatus {
            case .notDetermined:
                Button("Turn on event reminders") {
                    Task {
                        await EventReminders.requestPermissionIfNeeded()
                        await EventReminders.reschedule(context: context)
                        await refreshReminders()
                    }
                }
                .accessibilityIdentifier("reminders.turnOn")
            case .denied:
                Button("Open iPhone Settings to allow") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            default:
                HStack {
                    Text("Scheduled (next \(EventReminders.horizonDays) days)")
                    Spacer()
                    Text("\(pendingReminders)").foregroundStyle(.secondary)
                        .accessibilityIdentifier("reminders.count")
                }
                Button("Send a test reminder") {
                    Task { await EventReminders.sendTest() }
                }
                .accessibilityIdentifier("reminders.test")
            }
        } header: {
            Text("Event reminders")
        } footer: {
            Text("You get a notification when each calendar event starts.")
        }
    }

    private func refreshReminders() async {
        await EventReminders.reschedule(context: context)
        reminderStatus = await EventReminders.status()
        pendingReminders = await EventReminders.pendingCount()
    }

    @ViewBuilder private var statusRow: some View {
        switch xp.state {
        case .idle:
            HStack { Text("Status"); Spacer()
                Text("Not downloaded").foregroundStyle(.secondary) }
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 6) {
                Text("Downloading… \(Int(p * 100))%")
                ProgressView(value: p)
            }
        case .loading:
            HStack { Text("Status"); Spacer()
                Text("Loading…").foregroundStyle(.secondary) }
        case .ready:
            HStack { Text("Status"); Spacer()
                Text("Ready").foregroundStyle(.green) }
        case .failed(let msg):
            VStack(alignment: .leading) {
                Text("Failed").foregroundStyle(.red)
                Text(msg).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
