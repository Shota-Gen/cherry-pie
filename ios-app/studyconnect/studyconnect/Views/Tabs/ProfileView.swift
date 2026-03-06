//
//  ProfileView.swift
//  studyconnect
//
//  Created by Copilot on 3/6/26.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink("Edit Profile", destination: EditProfileView())
                NavigationLink("Settings", destination: SettingsView())
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
