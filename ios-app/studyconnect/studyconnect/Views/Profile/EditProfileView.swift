//
//  EditProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth

struct EditProfileView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var service = ProfileService()
    @State private var loadedProfile = UserProfile.blank()
    @State private var displayName = ""
    @State private var major = ""
    @State private var universityYear: Int? = nil
    @State private var profileImage = ""
    @State private var isInvisible = false
    @State private var saveMessage = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display Name", text: $displayName)
                TextField("Major", text: $major)
                Picker("Year", selection: $universityYear) {
                    Text("Not set").tag(nil as Int?)
                    ForEach(1...6, id: \.self) { year in
                        Text("Year \(year)").tag(year as Int?)
                    }
                }
                TextField("Profile Image URL", text: $profileImage)
            }

            Section("Privacy") {
                Toggle("Invisible Mode", isOn: $isInvisible)
            }

            Section {
                Button("Save Changes") {
                    var updated = loadedProfile
                    updated.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.major = major.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.universityYear = universityYear
                    updated.profileImage = profileImage.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.isInvisible = isInvisible
                    service.updateProfile(updated)
                    saveMessage = "Profile update stub sent."
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !saveMessage.isEmpty {
                Section {
                    Text(saveMessage).font(.footnote).foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            let p = service.fetchProfile(email: supabase.session?.user.email)
            loadedProfile = p
            displayName = p.displayName
            major = p.major
            universityYear = p.universityYear
            profileImage = p.profileImage
            isInvisible = p.isInvisible
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(SupabaseManager.shared)
}
