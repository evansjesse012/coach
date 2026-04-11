import SwiftUI
import Supabase

@main
struct CoachApp: App {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @State private var dataService = DataService()

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                } else if isAuthenticated {
                    MainTabView()
                        .environment(dataService)
                } else {
                    AuthView(isAuthenticated: $isAuthenticated)
                }
            }
            .task {
                await checkAuth()
            }
        }
    }

    private func checkAuth() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            isAuthenticated = true
            await dataService.loadAll()
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }
}
