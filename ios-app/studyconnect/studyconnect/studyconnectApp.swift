//
//  studyconnectApp.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//  Updated by David Mar 6

import SwiftUI

@main
struct studyconnectApp: App {
    @StateObject var supabaseManager = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            // Point this back to ContentView
            ContentView()
                .environmentObject(supabaseManager)
        }
    }
}
