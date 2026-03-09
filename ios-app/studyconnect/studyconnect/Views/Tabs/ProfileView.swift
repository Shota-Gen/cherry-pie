//
//  ProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var service = ProfileService()
    @State private var profile = UserProfile(
        displayName: "",
        bio: "",
        major: "",
        graduationYear: ""
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName.isEmpty ? "Your Name" : profile.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(profile.major.isEmpty ? "Major" : profile.major)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(profile.bio.isEmpty ? "Add a short bio in Edit Profile." : profile.bio)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)

                NavigationLink(destination: EditProfileView()) {
                    HStack {
                        Text("Edit Profile")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }

                NavigationLink(destination: SettingsView()) {
                    HStack {
                        Text("Settings")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }

                Button {
                    Task {
                        await supabase.signOut()
                    }
                } label: {
                    HStack {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
            .navigationTitle("Profile")
            .onAppear {
                profile = service.fetchProfile()
            }
        }
    }
}

#Preview {
    ProfileView()
}
