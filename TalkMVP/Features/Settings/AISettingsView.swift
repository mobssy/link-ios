import SwiftUI

struct AISettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage(AIFeatureSettings.summary.key) private var aiSummaryEnabled = AIFeatureSettings.summary.defaultValue
    @AppStorage(AIFeatureSettings.search.key) private var aiSearchEnabled = AIFeatureSettings.search.defaultValue
    @AppStorage(AIFeatureSettings.meetingNotes.key) private var aiAutoMeetingNotesEnabled = AIFeatureSettings.meetingNotes.defaultValue
    @AppStorage(AIFeatureSettings.replySuggestions.key) private var aiReplySuggestionsEnabled = AIFeatureSettings.replySuggestions.defaultValue

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $aiSummaryEnabled) {
                    Label {
                        Text(languageManager.string("Conversation Summary"))
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.pink)
                    }
                }
                Toggle(isOn: $aiSearchEnabled) {
                    Label {
                        Text(languageManager.string("Search by Meaning"))
                    } icon: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.blue)
                    }
                }
                Toggle(isOn: $aiAutoMeetingNotesEnabled) {
                    Label {
                        Text(languageManager.string("Meeting Notes"))
                    } icon: {
                        Image(systemName: "note.text")
                            .foregroundStyle(.green)
                    }
                }
                Toggle(isOn: $aiReplySuggestionsEnabled) {
                    Label {
                        Text(languageManager.string("Reply Suggestions"))
                    } icon: {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text(languageManager.string("Meeting notes pull the decisions, tasks, dates and open questions out of a chat; open them from the chat's menu. Reply suggestions offer short answers above the message field when someone writes to you. Search by meaning finds \"dinner tonight\" when you search for \"dinner plans\". All of them use Apple Intelligence on device."))
            }
        }
        .navigationTitle(languageManager.string("AI Features"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
