//
//  AuthView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import SwiftData
import UIKit

/// The sign-in / sign-up screen. `footer` is laid out after the form, inside the same
/// scroll view, so whatever the caller adds (the test mode button) can never cover it.
struct AuthView<Footer: View>: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSignUp = false
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    private let footer: Footer

    init(@ViewBuilder footer: () -> Footer) {
        self.footer = footer()
    }

    private var appTitle: AttributedString {
        var str = AttributedString("L!NK")
        if let range = str.range(of: "!") {
            str[range].foregroundColor = Color.appPrimary
        }
        return str
    }

    // Scrolls when the content does not fit (landscape, a large text size, the keyboard
    // up) and keeps the portrait layout otherwise: the content is at least as tall as
    // the screen, so the spacers still push the form to the middle. The view respects
    // the safe area and the keyboard, so nothing sits under the status bar, the Dynamic
    // Island or the keyboard.
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 30) {
                        // 로고 영역
                        VStack(spacing: 16) {
                            // The app icon's glass bubble without its background, so it sits on the
                            // screen itself; the asset has a light and a dark rendering.
                            Image("LoginBubble")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .accessibilityHidden(true)

                            Text(appTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primary)
                        }
                        .padding(.top, 50)

                        Spacer(minLength: 0)

                        // 폼 영역 (다크 모드에서 다크 그레이 래퍼 적용)
                        Group {
                            if colorScheme == .dark {
                                formContent
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                    )
                                    .padding(.horizontal, 16)
                            } else {
                                formContent
                                    .padding(.horizontal, 32)
                            }
                        }

                        Spacer(minLength: 0)

                        footer
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .screenCentered()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .tint(.appPrimaryText)
        }
    }

    private var authForm: some View {
        VStack(spacing: 16) {
            CustomTextField(
                text: $username,
                placeholder: isSignUp
                    ? languageManager.string("Username")
                    : languageManager.string("Username or Email"),
                icon: "person.fill"
            )

            if isSignUp {
                CustomTextField(
                    text: $displayName,
                    placeholder: languageManager.string("Display Name"),
                    icon: "person.crop.circle.fill"
                )
                CustomTextField(
                    text: $email,
                    placeholder: languageManager.string(LocalizedStringResource("Email", comment: "Placeholder of the email address field")),
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )
            }

            CustomTextField(
                text: $password,
                placeholder: languageManager.string("Password"),
                icon: "lock.fill",
                isSecure: true
            )

            if isSignUp {
                CustomTextField(
                    text: $confirmPassword,
                    placeholder: languageManager.string("Confirm Password"),
                    icon: "lock.fill",
                    isSecure: true
                )
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            authForm
                .frame(maxWidth: 360)

            // 오류 메시지
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // 로그인/회원가입 버튼
            Button(action: handleAuth) {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .onAppPrimary))
                } else {
                    Text(isSignUp ? languageManager.string("Sign Up") : languageManager.string("Sign In"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: 360)
            .frame(height: 50)
            .background(Color.appPrimary)
            .foregroundStyle(.onAppPrimary)
            .clipShape(.rect(cornerRadius: 25))
            .disabled(authManager.isLoading || !isFormValid)

            // SSO 버튼 (로그인 화면에서만)
            if !isSignUp {
                SSOSignInView()
            }

            // 전환 버튼
            Button(action: {
                withAnimation {
                    isSignUp.toggle()
                    clearForm()
                }
            }) {
                Text(isSignUp
                     ? languageManager.string("Already have an account? Sign In")
                     : languageManager.string("Don't have an account? Sign Up"))
                    .foregroundStyle(.appPrimaryText)
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !username.isEmpty && !displayName.isEmpty && !email.isEmpty &&
                   !password.isEmpty && password == confirmPassword && password.count >= 6
        } else {
            return !username.isEmpty && !password.isEmpty
        }
    }

    private func handleAuth() {
        Task {
            if isSignUp {
                await authManager.signUp(username: username, displayName: displayName, email: email, password: password)
            } else {
                await authManager.signIn(username: username, password: password)
            }
        }
    }

    private func clearForm() {
        username = ""
        displayName = ""
        email = ""
        password = ""
        confirmPassword = ""
        authManager.errorMessage = nil
    }
}

extension AuthView where Footer == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}

// 커스텀 텍스트 필드
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(keyboardType)
            }
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    if let container = try? ModelContainer(for: User.self) {
        AuthView()
            .environment(AuthManager(modelContext: ModelContext(container)))
            .environment(LanguageManager())
    } else {
        Text(verbatim: "Preview unavailable")
    }
}
