//
//  AppConfig.swift
//  wishywashy
//
//  Which data the app uses. Sample mode is the default and needs no setup.
//  Live mode is opt-in through launch arguments (Xcode: Product > Scheme > Edit Scheme > Run > Arguments),
//  so no project URL or key ever lives in source or in git:
//
//      -dataSource live -supabaseURL https://YOUR-PROJECT-REF.supabase.co -supabaseAnonKey YOUR-ANON-OR-PUBLISHABLE-KEY
//
//  A launch argument "-name value" is readable through UserDefaults, so no parsing is needed.
//

import Foundation

struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String
}

struct AppConfig {
    enum DataSource: String {
        case sample, live
    }

    let dataSource: DataSource
    /// Nil unless both launch arguments are present and the URL is a valid http(s) address
    let supabase: SupabaseConfig?

    static let current = AppConfig()

    init(defaults: UserDefaults = .standard) {
        dataSource = defaults.string(forKey: "dataSource") == "live" ? .live : .sample

        let rawURL = defaults.string(forKey: "supabaseURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = defaults.string(forKey: "supabaseAnonKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: rawURL), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host?.isEmpty == false, !key.isEmpty {
            supabase = SupabaseConfig(url: url, anonKey: key)
        } else {
            supabase = nil
        }
    }

    var isLive: Bool { dataSource == .live }
}
