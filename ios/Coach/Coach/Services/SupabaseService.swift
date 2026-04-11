import Foundation
import Supabase

/// Central Supabase client configuration.
/// Replace placeholder values with your actual Supabase project credentials.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // TODO: Replace with your Supabase project URL and anon key
        // These are safe to embed in the app — RLS protects the data
        let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
        let supabaseAnonKey = "YOUR_ANON_KEY"

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
    }
}
