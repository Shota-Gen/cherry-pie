//
//  ProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth
import UIKit

struct ProfileView: View {
    @Environment(\.supabaseManager) var supabase
    @State private var service = ProfileService()
    @State private var profile = UserProfile.blank()
    @State private var isGhostModeEnabled = true
    @State private var isPushNotificationsEnabled = true
    @State private var didCopyUID = false
    @State private var isLoadingProfile = false
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        AvatarView(name: displayName, imageURL: profile.profileImage, size: 108)
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)

                        Text(displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Button {
                            UIPasteboard.general.string = userIDText
                            didCopyUID = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_400_000_000)
                                didCopyUID = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("UID: \(userIDText)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: didCopyUID ? "checkmark" : "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text("45h")
                            .font(.system(size: 34, weight: .bold))
                        Text("FOCUS TIME")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                    VStack(spacing: 14) {
                        NavigationLink(destination: EditProfileView()) {
                            actionRow(
                                title: "Edit Profile",
                                icon: "person.crop.circle",
                                iconColor: .blue,
                                subtitle: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            actionRow(
                                title: "Change Password",
                                icon: "lock.circle",
                                iconColor: .blue,
                                subtitle: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 14) {
                            Image(systemName: "eye.slash.circle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Color.purple)
                                .frame(width: 40, height: 40)
                                .background(Color.purple.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ghost Mode")
                                    .font(.headline)
                                Text("hide location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $isGhostModeEnabled)
                                .labelsHidden()
                                .tint(.purple)
                                .disabled(isLoadingProfile || supabase.session == nil)
                                .onChange(of: isGhostModeEnabled) { _, newValue in
                                    guard let userId = supabase.session?.user.id else { return }
                                    Task {
                                        do {
                                            try await service.updateGhostMode(enabled: newValue, userId: userId)
                                            profile.isInvisible = newValue
                                        } catch {
                                            isGhostModeEnabled = profile.isInvisible
                                            print("Ghost mode update failed: \(error)")
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)

                        HStack(spacing: 14) {
                            Image(systemName: "bell.circle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Color.yellow)
                                .frame(width: 40, height: 40)
                                .background(Color.yellow.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push Notifications")
                                    .font(.headline)
                            }

                            Spacer()

                            Toggle("", isOn: $isPushNotificationsEnabled)
                                .labelsHidden()
                                .tint(.yellow)
                                .disabled(isLoadingProfile || supabase.session == nil)
                                .onChange(of: isPushNotificationsEnabled) { _, newValue in
                                    guard let userId = supabase.session?.user.id else { return }
                                    Task { await service.updatePushNotifications(enabled: newValue, userId: userId) }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
                    }

                    // Account actions
                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.red.opacity(0.25), radius: 12, y: 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadProfile() }
            .confirmationDialog(
                "Are you sure you want to sign out?",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await supabase.signOut()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var displayName: String {
        let title = profile.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        if let email = supabase.session?.user.email, !email.isEmpty { return email }
        return isLoadingProfile ? "Loading..." : "Profile"
    }

    private var userIDText: String {
        let uuid = supabase.session?.user.id ?? profile.userId
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        return String(uuidString)
    }

    private var cardBackground: some ShapeStyle {
        Color(.systemBackground)
    }

    private func actionRow(
        title: String,
        icon: String,
        iconColor: Color,
        subtitle: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }

    private func loadProfile() async {
        guard let session = supabase.session else {
            await MainActor.run {
                profile = .blank()
                isGhostModeEnabled = false
            }
            return
        }

        do {
            let p = try await service.fetchMyProfile(userId: session.user.id, fallbackEmail: session.user.email)
            await MainActor.run {
                profile = p
                isGhostModeEnabled = p.isInvisible
            }
        } catch {
            print("Profile load failed: \(error)")
        }
    }
}

#Preview {
    ProfileView()
}
