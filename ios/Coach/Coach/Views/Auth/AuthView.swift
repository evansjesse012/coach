import SwiftUI
import AuthenticationServices
import Supabase
import Auth

struct AuthView: View {
    @Binding var isAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / Title
            VStack(spacing: 8) {
                Text("Coach")
                    .font(CoachFonts.display(40, weight: .bold))
                Text("AI-Powered Training")
                    .font(CoachFonts.ui(16))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Divider
            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                Text("or")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            }

            // Email / Password
            VStack(spacing: 12) {
                CoachInput(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .font(CoachFonts.ui(15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error = errorMessage {
                    Text(error)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(CoachColors.red)
                }

                CoachButton(
                    label: isSignUp ? "Create Account" : "Sign In",
                    isDisabled: email.isEmpty || password.isEmpty || isLoading
                ) {
                    Task { await handleEmailAuth() }
                }

                Button(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up") {
                    isSignUp.toggle()
                    errorMessage = nil
                }
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Auth Handlers

    private func handleEmailAuth() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            } else {
                try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            }
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Failed to get Apple ID token"
                return
            }
            do {
                try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: token)
                )
                isAuthenticated = true
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
