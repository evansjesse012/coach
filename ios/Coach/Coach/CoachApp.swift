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
                        .preferredColorScheme(preferredScheme)
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

    /// Maps the user's appearance preference to SwiftUI's ColorScheme.
    /// .system returns nil so the OS scheme passes through.
    private var preferredScheme: ColorScheme? {
        switch dataService.settings.effectiveAppearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Auto-sign-in as the dev user. Skips the Auth UI for single-user testing.
    /// Replace with real auth flow (AuthView) when ready for multi-user.
    private func silentSignIn() async {
        isLoading = true
        errorMessage = nil
        do {
            let client = SupabaseService.shared.client

            // Reuse a cached session only if it's still valid. The SDK's
            // `Session.isExpired` includes a 30-second buffer, so we won't
            // fire requests against a token that's about to die. If the
            // cached session is missing or expired, fall through and mint
            // a fresh one via signIn below.
            if let session = try? await client.auth.session, !session.isExpired {
                isAuthenticated = true
                await dataService.loadAll()
                isLoading = false
                return
            }

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
