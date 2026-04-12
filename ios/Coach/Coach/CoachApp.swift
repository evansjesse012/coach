import SwiftUI
import Supabase
import Auth

// TODO: Move to .xcconfig or env vars before making the repo public.
// Dev credentials for silent auto-login during single-user testing.
private let DEV_USER_EMAIL = "evansjesse012@gmail.com"
private let DEV_USER_PASSWORD = "CoachApp1234!$"

@main
struct CoachApp: App {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dataService = DataService()

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    ProgressView("Signing in…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                } else if isAuthenticated {
                    MainTabView()
                        .environment(dataService)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text("Sign-in failed")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await silentSignIn() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task {
                await silentSignIn()
            }
        }
    }

    /// Auto-sign-in as the dev user. Skips the Auth UI for single-user testing.
    /// Replace with real auth flow (AuthView) when ready for multi-user.
    private func silentSignIn() async {
        isLoading = true
        errorMessage = nil
        do {
            let client = SupabaseService.shared.client

            // If a session already exists (from Supabase's local storage), use it.
            if let _ = try? await client.auth.session {
                isAuthenticated = true
                await dataService.loadAll()
                isLoading = false
                return
            }

            // Otherwise, sign in with the dev credentials.
            try await client.auth.signIn(email: DEV_USER_EMAIL, password: DEV_USER_PASSWORD)
            isAuthenticated = true
            await dataService.loadAll()
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        isLoading = false
    }
}
