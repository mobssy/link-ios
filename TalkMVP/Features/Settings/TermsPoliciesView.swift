import SwiftUI

struct TermsPoliciesView: View {
    @Environment(LanguageManager.self) var languageManager
    @State private var selectedSegment = 0

    private enum Segment: Int, CaseIterable {
        case terms
        case privacy

        var title: LocalizedStringResource {
            switch self {
            case .terms:
                return LocalizedStringResource("Terms", comment: "Segment that shows the terms of service")
            case .privacy:
                return LocalizedStringResource("Privacy", comment: "Segment that shows the privacy policy")
            }
        }

        var placeholder: LocalizedStringResource {
            switch self {
            case .terms:
                return LocalizedStringResource(
                    "terms.placeholder",
                    defaultValue: """
                    These terms govern the conditions of service use. Users must understand and agree to these terms to use the service.
                    The terms detail the rights and obligations of the service provider and the responsibilities of the users.
                    All issues arising during the use of the service are governed by these terms.
                    """,
                    comment: "Placeholder text of the terms of service"
                )
            case .privacy:
                return LocalizedStringResource(
                    "privacy.placeholder",
                    defaultValue: """
                    The privacy policy explains principles regarding collection, use, storage, and disposal of personal information to protect users.
                    We manage users' personal data securely and obtain clear consent before providing it to third parties.
                    Rights concerning personal information are protected by applicable laws.
                    """,
                    comment: "Placeholder text of the privacy policy"
                )
            }
        }
    }

    private var segment: Segment {
        Segment(rawValue: selectedSegment) ?? .terms
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(languageManager.string(segment.placeholder))
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("", selection: $selectedSegment) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    Text(languageManager.string(segment.title)).tag(segment.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .background(.bar)
        }
        .animation(.none, value: selectedSegment)
        .navigationTitle(languageManager.string("Terms & Policies"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TermsPoliciesView()
            .environment(LanguageManager())
    }
}
