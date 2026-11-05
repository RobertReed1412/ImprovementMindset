import SwiftUI

/// Chat screen that asks the workout coach (n8n AI agent) about logged training.
struct AskCoachView: View {
    private struct Message: Identifiable {
        let id = UUID()
        let isFromUser: Bool
        let text: String
    }

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    @State private var question = ""
    @State private var isThinking = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            Text(message.text)
                                .foregroundStyle(Theme.Palette.bone)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(
                                    message.isFromUser ? Theme.Palette.gold.opacity(0.25) : Theme.Palette.nightRaised,
                                    in: .rect(cornerRadius: 12)
                                )
                                .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
                                .id(message.id)
                        }
                        if isThinking {
                            ProgressView()
                                .tint(Theme.Palette.goldBright)
                                .padding(.leading, 12)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .overlay {
                if messages.isEmpty {
                    ContentUnavailableView(
                        "Ask about your training",
                        systemImage: "figure.run",
                        description: Text("Try “How many hours did I fight this month?”")
                    )
                    .foregroundStyle(Theme.Palette.boneDim)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Ask about your training…", text: $question)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit(send)
                    Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundStyle(Theme.Palette.goldBright)
                        .disabled(trimmedQuestion.isEmpty || isThinking)
                }
                .padding()
                .background(Theme.Palette.nightDeep)
            }
            .nightBackground()
            .navigationTitle("Ask Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let text = trimmedQuestion
        guard !text.isEmpty, !isThinking else { return }

        question = ""
        messages.append(Message(isFromUser: true, text: text))
        isThinking = true

        Task {
            let reply: String
            do {
                reply = try await RAGClient.shared.ask(text)
            } catch {
                reply = "Couldn't reach the coach: \(error.localizedDescription)"
            }
            messages.append(Message(isFromUser: false, text: reply))
            isThinking = false
        }
    }
}

#Preview { AskCoachView() }
