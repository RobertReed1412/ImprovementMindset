import SwiftUI
import SwiftData

struct SettingsView: View {
    private var xp: LocalXPService { LocalXPService.shared }

    var body: some View {
        NavigationStack {
            Form {
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
        }
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
