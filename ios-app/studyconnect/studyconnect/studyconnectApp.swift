//
//  studyconnectApp.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//  Updated by David Mar 6

import SwiftUI

/// App entry point. Injects the shared SupabaseManager singleton into the
/// SwiftUI environment so every view can access auth state and the Supabase
/// client via `@Environment(\.supabaseManager)`.  No @StateObject needed —
/// SupabaseManager is @Observable.
@main
struct studyconnectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject auth/backend singleton into the view hierarchy
                .environment(\.supabaseManager, SupabaseManager.shared)
        }
    }
}
