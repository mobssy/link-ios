import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage(AccessibilityPreferences.boldTextKey) private var boldText = false
    @AppStorage(AccessibilityPreferences.reduceMotionKey) private var inAppReducesMotion = false
    @AppStorage(AccessibilityPreferences.highContrastKey) private var inAppHighContrast = false
    // What applies: the switches below or the matching iOS settings. The preview shows these.
    @Environment(\.prefersReducedMotion) private var reduceMotion
    @Environment(\.prefersHighContrast) private var highContrast
    @AppStorage(InAppTextSize.stepKey) private var textSizeStep = InAppTextSize.defaultStep
    @AppStorage(InAppTextSize.overridesKey) private var overridesSystemTextSize = false

    // MARK: - Text Size Helpers

    private var textSizeLabel: String {
        let labels: [LocalizedStringResource] = [
            LocalizedStringResource("Small", comment: "Text size step"),
            LocalizedStringResource("Medium", comment: "Text size step"),
            LocalizedStringResource("Default", comment: "Text size step"),
            LocalizedStringResource("Large", comment: "Text size step"),
            LocalizedStringResource("Extra Large", comment: "Text size step")
        ]
        let step = labels.indices.contains(textSizeStep) ? textSizeStep : 2
        return languageManager.string(labels[step])
    }

    var body: some View {
        Form {
            // MARK: - Text Size Section
            Section {
                Toggle(isOn: $overridesSystemTextSize.animation(reduceMotion ? nil : .default)) {
                    Label(
                        languageManager.string("Custom Text Size"),
                        systemImage: "textformat.size"
                    )
                }
                .accessibilityIdentifier("customTextSizeToggle")

                if overridesSystemTextSize {
                    VStack(spacing: 14) {
                        // Aa size indicator
                        HStack(alignment: .bottom, spacing: 0) {
                            Text("Aa")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            ForEach(0..<5) { i in
                                Capsule()
                                    .fill(i <= textSizeStep ? Color.appPrimaryText : Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: CGFloat(10 + i * 5))
                                    .padding(.horizontal, 2)
                            }
                            Spacer()
                            Text("Aa")
                                .font(.title2)
                                .foregroundStyle(Color.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(textSizeStep) },
                                set: { textSizeStep = Int($0.rounded()) }
                            ),
                            in: Double(InAppTextSize.steps.lowerBound)...Double(InAppTextSize.steps.upperBound),
                            step: 1
                        )
                        .tint(.appPrimaryText)
                        .accessibilityLabel(languageManager.string("Text Size"))
                        .accessibilityValue(textSizeLabel)

                        Text(textSizeLabel)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: textSizeStep)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text(languageManager.string("Text Size"))
            } footer: {
                if overridesSystemTextSize {
                    Text(languageManager.string("Applies this size to all text in the app right away, instead of the iOS setting."))
                } else {
                    Text(languageManager.string("Follows the text size in iOS Settings → Accessibility → Display & Text Size."))
                }
            }

            // MARK: - Visual Settings Section
            Section {
                Toggle(isOn: $boldText) {
                    Label(
                        languageManager.string("Bold Text"),
                        systemImage: "bold"
                    )
                }
                .accessibilityIdentifier("boldTextToggle")

                Toggle(isOn: $inAppReducesMotion) {
                    Label(
                        languageManager.string("Reduce Motion"),
                        systemImage: "circle.dotted"
                    )
                }
                .accessibilityIdentifier("reduceMotionToggle")

                Toggle(isOn: $inAppHighContrast) {
                    Label(
                        languageManager.string("High Contrast Bubbles"),
                        systemImage: "circle.lefthalf.filled"
                    )
                }
                .accessibilityIdentifier("highContrastToggle")
            } header: {
                Text(languageManager.string("In-App Settings"))
            } footer: {
                // The iOS features themselves are set in iOS; the app follows them without a row each.
                Text(languageManager.string("These apply right away. The app also follows your iOS accessibility settings, such as VoiceOver, larger text and Reduce Motion."))
            }

            // MARK: - Preview Section
            Section {
                previewBubbles
            } header: {
                Text(languageManager.string(LocalizedStringResource("Preview", comment: "Section header above sample message bubbles")))
            }
        }
        .navigationTitle(languageManager.string("Accessibility"))
        .navigationBarTitleDisplayMode(.inline)
        // Apply bold and size in this view so Preview section reflects changes live
    }

    // MARK: - Live Preview Bubbles
    private var previewBubbles: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text(languageManager.string("Hello! This is a preview message."))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.ownBubble(highContrast: highContrast))
                    )
                    .foregroundStyle(Color.onOwnBubble(highContrast: highContrast))
            }
            HStack {
                Text(languageManager.string("Nice to meet you! Can you see this?"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(highContrast ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                    )
                    .foregroundStyle(Color.primary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: highContrast)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: boldText)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: textSizeStep)
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
            .environment(LanguageManager())
    }
}
