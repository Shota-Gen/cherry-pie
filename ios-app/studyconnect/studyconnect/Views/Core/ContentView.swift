//
//  ContentView.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//

import SwiftUI

/// Root auth gate.  Reads the session from SupabaseManager via @Environment.
/// When a session exists → shows the main TabView (Map, Friends, Profile).
/// When nil → shows LoginView.  No business logic lives here.
struct ContentView: View {
    // Injected via custom EnvironmentKey so every view can read auth state
    @Environment(\.supabaseManager) var supabase

    var body: some View {
        // Auth gate: session presence determines which UI tree is rendered.
        // When a session exists the user sees the main three-tab interface;
        // when nil (logged out or first launch) the login screen is shown instead.
        if supabase.session != nil {
            // Main app TabView — three tabs: Map, Friends, Profile.
            // SwiftUI re-evaluates this `if` automatically whenever
            // supabase.session changes because SupabaseManager is @Observable.
            TabView {
                MapView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }

                FriendsView()
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        } else {
            // No session → show the Google OAuth login screen
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
