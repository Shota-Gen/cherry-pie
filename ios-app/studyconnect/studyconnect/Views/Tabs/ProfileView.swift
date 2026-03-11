//
//  ProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var service = ProfileService()
    @State private var profile = UserProfile.blank()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    AvatarView(name: profile.displayName.isEmpty ? (supabase.session?.user.email ?? "") : profile.displayName,
                               imageURL: profile.profileImage,
                               size: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName.isEmpty ? "Your Name" : profile.displayName)
                            .font(.title3).fontWeight(.semibold)
                        Text(supabase.session?.user.email ?? "")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account").font(.caption).foregroundColor(.gray)
                    Text(supabase.session?.user.email ?? "")
                    Text("Major: \(profile.major.isEmpty ? "Not set" : profile.major)")
                    Text("Year: \(profile.universityYear.map(String.init) ?? "Not set")")
                    Text("Study Spot: \(profile.studySpot.isEmpty ? "Not Found" : profile.studySpot)")
                    Text(profile.isInvisible ? "Visibility: Hidden" : "Visibility: Visible")
                }
                .font(.body)
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
                profile = service.fetchProfile(email: supabase.session?.user.email)
            }
        }
    }
}

#Preview {
    ProfileView()
}
