//
//  ContentView.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
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
