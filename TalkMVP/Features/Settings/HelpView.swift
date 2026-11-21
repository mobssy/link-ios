import SwiftUI
import MessageUI
import os

private let helpLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "HelpView")

struct HelpView: View {
    @Environment(LanguageManager.self) var languageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSupportSheet = false
    @State private var showingMailComposer = false
    @State private var expandedSections: Set<String> = []

    // MARK: - FAQ Categories
    enum FAQCategory: String, CaseIterable {
        case gettingStarted
        case messaging
        case friends
        case notifications
        case accountSettings
        case troubleshooting

        var title: LocalizedStringResource {
            switch self {
            case .gettingStarted: return "Getting Started"
            case .messaging: return LocalizedStringResource("Messaging", comment: "Help FAQ category about sending messages")
            case .friends: return "Friends"
            case .notifications: return "Notifications"
            case .accountSettings: return "Account & Settings"
            case .troubleshooting: return "Troubleshooting"
            }
        }

        func icon() -> String {
            switch self {
            case .gettingStarted: return "star.fill"
            case .messaging: return "message.fill"
            case .friends: return "person.2.fill"
            case .notifications: return "bell.fill"
            case .accountSettings: return "gearshape.fill"
            case .troubleshooting: return "wrench.and.screwdriver.fill"
            }
        }
    }

    struct FAQItem: Identifiable {
        let id = UUID()
        let category: FAQCategory
        let question: LocalizedStringResource
        let answers: [LocalizedStringResource]
    }

    private var allFAQs: [FAQItem] {
        [
            // Getting Started
            FAQItem(category: .gettingStarted, question: "I'm new to the app. How do I get started?", answers: ["1. Set up your profile (name, photo)", "2. Add friends from the Friends tab", "3. Start chatting from the Chats tab"]),
            FAQItem(category: .gettingStarted, question: "How do I set up my profile?", answers: ["Tap your profile in the Friends tab to change your name, status message, and profile photo."]),

            // Messaging
            FAQItem(category: .messaging, question: "Messages aren't sending", answers: ["Check your network connection (Wi-Fi or cellular data)", "Try restarting the app"]),
            FAQItem(category: .messaging, question: "How do I send photos/videos?", answers: ["Tap the + button on the left of the message input to select photos/videos."]),
            FAQItem(category: .messaging, question: "Can I delete sent messages?", answers: ["Long press a message and select 'Delete'. You can only delete your own messages."]),
            FAQItem(category: .messaging, question: "How do I search previous messages?", answers: ["Tap the search icon at the top of the chat to search by keyword."]),

            // Friends
            FAQItem(category: .friends, question: "How do I add friends?", answers: ["Friends tab → + button → Search by email and send a friend request."]),
            FAQItem(category: .friends, question: "How do I block a friend?", answers: ["Swipe left on a friend in the list and select 'Block'."]),
            FAQItem(category: .friends, question: "What are favorite friends?", answers: ["Swipe right on a friend and add a star to show them in the favorites section."]),

            // Notifications
            FAQItem(category: .notifications, question: "I'm not receiving notifications", answers: ["Check Settings → Notifications and ensure TalkMVP notifications are enabled.", "Check Focus mode or Do Not Disturb settings."]),
            FAQItem(category: .notifications, question: "How do I mute a specific chat?", answers: ["Tap the bell icon at the top right of the chat to toggle notifications."]),

            // Account & Settings
            FAQItem(category: .accountSettings, question: "How do I change the language?", answers: ["Settings → Language, then pick your language."]),
            FAQItem(category: .accountSettings, question: "How do I change the theme?", answers: ["Settings → Theme → Select Light/Dark/System mode."]),
            FAQItem(category: .accountSettings, question: "I forgot my password", answers: ["Select 'Reset Password' on the login screen.", "A reset link will be sent to your registered email."]),
            FAQItem(category: .accountSettings, question: "How do I delete my account?", answers: ["Settings → Delete Account.", "⚠️ Deleted accounts cannot be recovered, and all conversations are permanently deleted."]),

            // Troubleshooting
            FAQItem(category: .troubleshooting, question: "The app is slow", answers: ["Force quit the app and restart it.", "Restart your device."]),
            FAQItem(category: .troubleshooting, question: "The app crashes frequently", answers: ["Make sure you're on the latest version. If the problem persists, contact support."]),
        ]
    }

    private func faqsByCategory(_ category: FAQCategory) -> [FAQItem] {
        allFAQs.filter { $0.category == category }
    }

    var body: some View {
        List {
            // Quick Guides Section
            Section {
                QuickGuideRow(
                    icon: "hand.tap.fill",
                    title: languageManager.string("Add Reactions"),
                    description: languageManager.string("Long press a message to add emoji reactions.")
                )
                QuickGuideRow(
                    icon: "arrowshape.turn.up.left.fill",
                    title: languageManager.string("Reply to Messages"),
                    description: languageManager.string("Swipe left on a message to reply.")
                )
                QuickGuideRow(
                    icon: "character.bubble.fill",
                    title: languageManager.string("Message Translation"),
                    description: languageManager.string("Enable auto-translation in Settings → Translation.")
                )
            } header: {
                Text(languageManager.string("Quick Guides"))
            }

            // FAQ Categories
            Section {
                ForEach(FAQCategory.allCases, id: \.self) { category in
                    FAQCategoryView(
                        category: category,
                        faqs: faqsByCategory(category),
                        isExpanded: expandedSections.contains(category.rawValue)
                    ) {
                        toggleSection(category.rawValue)
                    }
                }
            } header: {
                Text(languageManager.string("FAQs"))
            }

            // Support Section
            Section {
                Button {
                    sendEmail()
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.appPrimaryText)
                        Text(languageManager.string("Email Support"))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.secondary)
                            .font(.caption)
                    }
                }

                Button {
                    showingSupportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundStyle(.appPrimaryText)
                        Text(languageManager.string("Send Feedback"))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text(languageManager.string("Contact Support"))
            }

            // App Version
            Section {
                HStack {
                    Text(languageManager.string("App Version"))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(getAppVersion())
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .navigationTitle(languageManager.string("Help"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSupportSheet) {
            FeedbackView()
                .environment(languageManager)
        }
    }

    private func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }

    private func sendEmail() {
        let email = "support@linkmvp.com"
        let subject = languageManager.string("TalkMVP Support Request")
        let body = languageManager.string("Please describe your issue:\n\nApp Version: \(getAppVersion())")

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Quick Guide Row
struct QuickGuideRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.appPrimaryText)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FAQ Category View
struct FAQCategoryView: View {
    let category: HelpView.FAQCategory
    let faqs: [HelpView.FAQItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: category.icon())
                        .foregroundStyle(.appPrimaryText)
                        .frame(width: 24)

                    Text(languageManager.string(category.title))
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 8)
                // Plain-style buttons only hit-test drawn content; make the Spacer tappable too.
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(faqs) { faq in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "Q. \(languageManager.string(faq.question))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primary)

                            ForEach(faq.answers.map { languageManager.string($0) }, id: \.self) { answer in
                                Text(verbatim: "• \(answer)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.leading, 36)

                        if faq.id != faqs.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(LanguageManager.self) var languageManager
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $feedbackText)
                    .padding()
                    .overlay(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text(languageManager.string("Share your feedback..."))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .navigationTitle(languageManager.string("Send Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.string("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.string(LocalizedStringResource("Send", comment: "Button that sends the written feedback"))) {
                        sendFeedback()
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(languageManager.string("Feedback Sent"), isPresented: $showingConfirmation) {
                Button(languageManager.string("OK")) {
                    dismiss()
                }
            } message: {
                Text(languageManager.string("Thank you for your feedback!"))
            }
        }
    }

    private func sendFeedback() {
        // TODO: Implement actual feedback submission to backend
        helpLogger.info("Feedback submitted: \(feedbackText, privacy: .private)")
        showingConfirmation = true
    }
}

#Preview {
    NavigationStack {
        HelpView()
            .environment(LanguageManager())
    }
}
