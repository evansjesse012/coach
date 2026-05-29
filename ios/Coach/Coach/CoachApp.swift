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
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && isAuthenticated {
                    // Snap any running rest timer back to real elapsed time —
                    // the ticking task is suspended while backgrounded.
                    dataService.refreshRestTimer()
                    Task { await dataService.preGenerateOnForeground() }
                }
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

            // Always burn the cached session and mint a fresh one on launch.
            // The SDK's `Session.isExpired` check catches time-based expiry,
            // but not server-side revocation (JWT secret rotation, project
            // changes, etc.) — and those produce the same "Invalid JWT" 401
            // from Supabase's API gateway. For a single-user dev app, one
            // extra auth round-trip per launch is a trivial cost vs. ever
            // getting stuck on a stale keychain session again.
            try? await client.auth.signOut()
            try await client.auth.signIn(email: DEV_USER_EMAIL, password: DEV_USER_PASSWORD)
            isAuthenticated = true
            await dataService.loadAll()
            // Restore any in-progress strength workout that was active when
            // the app was last killed or backgrounded out of memory.
            dataService.restoreActiveWorkoutFromDisk()
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        isLoading = false
    }
}
