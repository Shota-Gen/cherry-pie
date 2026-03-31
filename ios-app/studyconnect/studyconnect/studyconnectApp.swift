//
//  studyconnectApp.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//  Updated by David Mar 6

import SwiftUI

@main
struct studyconnectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.supabaseManager, SupabaseManager.shared)
        }
    }
}
