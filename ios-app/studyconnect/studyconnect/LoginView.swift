//
//  ContentView.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//

import SwiftUI
import Auth

struct LoginView: View {
    // This connects to the manager we set up in the App file
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
        VStack {
            if let user = supabase.session?.user {
                Text("Logged in as \(user.email ?? "Unknown")")
                Text("Device ID Linked!")
                    .font(.caption)
            } else {
                Button("Sign in with Google") {
                    Task {
                        await supabase.signInWithGoogle()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ContentView()
}
