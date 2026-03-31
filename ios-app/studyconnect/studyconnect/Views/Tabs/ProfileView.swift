//
//  ProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth
import UIKit

/// Profile tab — displays the user’s avatar, UID (tap to copy), focus time stat,
/// ghost mode / push notification toggles, and sign-out.  Loads profile data
/// from Supabase on appear.  Ghost mode toggle immediately syncs to backend.
struct ProfileView: View {
    @Environment(\.supabaseManager) var supabase           // auth session for user ID and email
    @State private var service = ProfileService()           // Supabase profile CRUD operations
    @State private var profile = UserProfile.blank()        // loaded profile data from backend
    @State private var isGhostModeEnabled = true             // "hide location" toggle synced to backend
    @State private var isPushNotificationsEnabled = true     // push notification preference
    @State private var didCopyUID = false                    // shows checkmark after UID is copied
    @State private var isLoadingProfile = false              // prevents toggling while loading
    @State private var showingSignOutConfirmation = false    // confirmation dialog before sign-out

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ── Avatar + Name + UID section ──
                    VStack(spacing: 12) {
                        // Profile picture — uses AvatarView which falls back to
                        // colored initials circle when no image URL is set
                        AvatarView(name: displayName, imageURL: profile.profileImage, size: 108)
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)

                        Text(displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        // Tappable UID pill — copies the user's UUID to clipboard.
                        // Shows a checkmark for 1.4 seconds after copying, then reverts.
                        Button {
                            UIPasteboard.general.string = userIDText
                            didCopyUID = true
                            // Auto-reset the copied indicator after a short delay
                            Task {
                                try? await Task.sleep(nanoseconds: 1_400_000_000)
                                didCopyUID = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("UID: \(userIDText)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                // Toggle between clipboard icon and checkmark
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

                    // ── Focus time stat card ──
                    // Hardcoded "45h" for now — will be replaced with real data
                    VStack(spacing: 8) {
                        Text("45h")
                            .font(.system(size: 34, weight: .bold))
                        Text("FOCUS TIME")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(1) // letter-spacing for the all-caps label
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                    // ── Settings rows section ──
                    VStack(spacing: 14) {
                        // Edit Profile — pushes EditProfileView onto the nav stack
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

                        // Change Password — placeholder action (not yet wired)
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

                        // ── Ghost Mode toggle ──
                        // When enabled, the user's location is hidden from friends.
                        // onChange fires an async call to the backend to persist the
                        // new value. On failure, reverts the toggle to its previous state.
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
                                            // Persist ghost mode preference to Supabase
                                            try await service.updateGhostMode(enabled: newValue, userId: userId)
                                            profile.isInvisible = newValue
                                        } catch {
                                            // Revert toggle on failure so UI matches backend
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

                        // ── Push Notifications toggle ──
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

                    // ── Sign Out button ──
                    // Shows a confirmation dialog before actually signing out.
                    // supabase.signOut() clears the Supabase session, which causes
                    // ContentView to switch from TabView back to LoginView.
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
            // .task runs the async loadProfile() when the view first appears
            .task { await loadProfile() }
            // Destructive confirmation dialog before sign-out
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

    // Falls back through: profile display name → email → "Loading..." / "Profile"
    private var displayName: String {
        let title = profile.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        if let email = supabase.session?.user.email, !email.isEmpty { return email }
        return isLoadingProfile ? "Loading..." : "Profile"
    }

    // Strips dashes from UUID for a cleaner display string
    private var userIDText: String {
        let uuid = supabase.session?.user.id ?? profile.userId
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        return String(uuidString)
    }

    private var cardBackground: some ShapeStyle {
        Color(.systemBackground)
    }

    // Reusable row builder for the settings section — icon + title + optional
    // subtitle + optional chevron, all in a card-style container.
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

    /// Loads the user's profile from Supabase on view appear.
    /// Falls back to a blank profile if no session exists.
    /// Synchronizes local toggle state (ghost mode) with the fetched data.
    private func loadProfile() async {
        guard let session = supabase.session else {
            profile = .blank()
            isGhostModeEnabled = false
            return
        }

        do {
            let p = try await service.fetchMyProfile(userId: session.user.id, fallbackEmail: session.user.email)
            profile = p
            isGhostModeEnabled = p.isInvisible
        } catch {
            print("Profile load failed: \(error)")
        }
    }
}

#Preview {
    ProfileView()
}
