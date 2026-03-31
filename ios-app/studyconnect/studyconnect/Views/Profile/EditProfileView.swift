//
//  EditProfileView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth

/// Edit profile form: avatar, display name, major, university year.
/// Loads the current profile on appear and saves changes to Supabase.
/// Year picker uses a Menu-based dropdown ("Year 1" through "Year 6+").
struct EditProfileView: View {
    @Environment(\.supabaseManager) var supabase          // auth session for user ID
    @Environment(\.dismiss) private var dismiss             // pops back to ProfileView on save
    @State private var service = ProfileService()           // Supabase profile read/write
    @State private var loadedProfile = UserProfile.blank()  // original profile snapshot — used as base for saves
    @State private var displayName = ""                     // text field binding
    @State private var major = ""                           // text field binding
    @State private var selectedYear = "Year 1"              // dropdown selection
    @State private var profileImage = ""                    // URL string (currently display-only)
    @State private var isLoadingProfile = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // ── Avatar with camera badge ──
                // Large avatar with a dashed blue border ring and a camera
                // icon badge in the bottom-right corner (photo upload placeholder).
                AvatarView(name: displayName, imageURL: profileImage, size: 112)
                    .overlay(
                        // Dashed circle border around the avatar
                        Circle()
                            .stroke(
                                Color.blue,
                                style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                            )
                            .padding(-6)  // extend slightly beyond the avatar
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    .overlay(alignment: .bottomTrailing) {
                        // Camera badge — visual affordance for future photo upload
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color(.systemBackground), lineWidth: 3)
                            )
                    }

                Text("Change Photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // ── Form fields: name, major, year ──
                VStack(spacing: 18) {
                    labeledTextField(title: "Full Name", text: $displayName, icon: "person")
                    labeledTextField(title: "Major", text: $major, icon: "book")
                    yearDropdownField  // Menu-style year picker
                }

                // ── Save button ──
                // Fires save() which upserts the profile to Supabase then dismisses.
                // Disabled while loading, saving, or when there's no session.
                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Saving..." : "Save Changes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.24), radius: 12, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingProfile || isSaving || supabase.session == nil)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        // Load current profile data into form fields on appear
        .task { await loadProfile() }
    }

    private let yearOptions = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5", "Year 6+"]

    /// Converts the display string ("Year 3") to an Int (3) for the backend.
    /// "Year 6+" maps to 6.
    private var parsedYear: Int? {
        if selectedYear == "Year 6+" {
            return 6
        }
        let digits = selectedYear.filter(\.isNumber)
        return Int(digits)
    }

    /// Reusable styled text field with a label header and an icon badge.
    /// Used for "Full Name" and "Major" fields.
    private func labeledTextField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField(title, text: text)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
        }
    }

    /// Year selector using Menu (dropdown) instead of a Picker.
    /// Shows a graduation cap icon and chevron-down affordance.
    private var yearDropdownField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Menu {
                ForEach(yearOptions, id: \.self) { option in
                    Button(option) {
                        selectedYear = option
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 38, height: 38)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(selectedYear)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    /// Fetches the user's profile from Supabase and populates all form fields.
    /// Called via .task when the view first appears.
    private func loadProfile() async {
        guard let session = supabase.session else { return }

        do {
            let p = try await service.fetchMyProfile(userId: session.user.id, fallbackEmail: session.user.email)
            loadedProfile = p
            displayName = p.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            major = p.major.trimmingCharacters(in: .whitespacesAndNewlines)
            profileImage = p.profileImage.trimmingCharacters(in: .whitespacesAndNewlines)
            if let universityYear = p.universityYear {
                selectedYear = universityYear >= 6 ? "Year 6+" : "Year \(universityYear)"
            }
        } catch {
            print("Edit profile load failed: \(error)")
        }
    }

    /// Saves edits back to Supabase. Builds an updated UserProfile from the
    /// original loadedProfile snapshot + current form field values, then calls
    /// ProfileService.updateProfile. On success, dismisses back to ProfileView.
    private func save() async {
        guard let session = supabase.session else { return }

        var updated = loadedProfile
        updated.userId = session.user.id
        updated.email = session.user.email ?? updated.email
        updated.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.major = major.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.profileImage = profileImage.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.universityYear = parsedYear

        do {
            try await service.updateProfile(updated)
            dismiss()
        } catch {
            print("Profile save failed: \(error)")
        }
    }
}

#Preview {
    EditProfileView()
        .environment(\.supabaseManager, SupabaseManager.shared)
}
