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
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var major: String = ""
    @State private var graduationYear: String = ""
    @State private var saveMessage: String = ""

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Display name", text: $displayName)
                TextField("Major", text: $major)
                TextField("Graduation year", text: $graduationYear)
                    .keyboardType(.numberPad)
            }

            Section("Bio") {
                TextField("Tell others how you like to study", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button("Save Changes") {
                    let updatedProfile = UserProfile(
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                        major: major.trimmingCharacters(in: .whitespacesAndNewlines),
                        graduationYear: graduationYear.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    service.updateProfile(updatedProfile)
                    saveMessage = "Profile update stub sent."
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !saveMessage.isEmpty {
                Section {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            let profile = service.fetchProfile(email: supabase.session?.user.email)
            displayName = profile.displayName
            bio = profile.bio
            major = profile.major
            graduationYear = profile.graduationYear
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(SupabaseManager.shared)
}
