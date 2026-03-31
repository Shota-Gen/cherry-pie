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
    @Environment(\.supabaseManager) var supabase

    var body: some View {
        // Auth gate: session presence determines which UI tree is rendered
        if supabase.session != nil {
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
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
