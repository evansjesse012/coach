import Foundation
import Supabase

/// Central Supabase client configuration.
/// Replace placeholder values with your actual Supabase project credentials.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // These are safe to embed in the app — RLS protects the data
        let supabaseURL = URL(string: "https://pfbcsdkbrjdwvrckcnbg.supabase.co")!
        let supabaseAnonKey = "sb_publishable_83nhtrTXoM1SvHMrV9BvMA_zIK7rkh0"

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
    }
}
