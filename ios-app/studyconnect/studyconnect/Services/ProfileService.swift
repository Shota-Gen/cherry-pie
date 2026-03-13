//
//  ProfileService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation

class ProfileService {
    // STUB: Fetch profile by email. Returns mock user data for development.
    func fetchProfile(email: String?) -> UserProfile {
        // TODO: Replace with real Supabase fetch using email as query parameter.
        return fetchProfileFromAPIStub(email: email)
    }

    // STUB: Fetch profile by user ID. Returns mock user data for development.
    func fetchProfileByID(userID: String) -> UserProfile {
        // TODO: Replace with real Supabase fetch using user_id as query parameter.
        return fetchProfileFromAPIStub(userID: userID)
    }

    // STUB: Update current user's profile on backend.
    func updateProfile(_ profile: UserProfile) {
        // TODO: Implement actual API call to PATCH /profiles/{user_id}
        print("Updating profile: \(profile)")
    }

    // STUB: Update ghost mode (invisibility) setting for current user.
    func updateGhostMode(enabled: Bool, userID: String) {
        // TODO: Implement actual API call to PATCH /profiles/{user_id} with { isInvisible: enabled }
        print("Updating ghost mode for user \(userID): \(enabled)")
    }

    // STUB: Update push notification preference for current user.
    func updatePushNotifications(enabled: Bool, userID: String) {
        // TODO: Implement actual API call to PATCH /profiles/{user_id} with { pushNotificationsEnabled: enabled }
        print("Updating push notifications for user \(userID): \(enabled)")
    }

    /// STUB: Returns mock test profile data for development.
    /// Replace with real Supabase query: SELECT * FROM public.users WHERE email = ? OR user_id = ?
    private func fetchProfileFromAPIStub(email: String? = nil, userID: String? = nil) -> UserProfile {
        // Mock data for testing
        let mockUserID = UUID(uuidString: "849302") ?? UUID()
        var profile = UserProfile(
            userId: mockUserID,
            displayName: "Alex Johnson",
            email: email ?? "alex.johnson@example.com",
            profileImage: "",
            studySpot: "Fishbowl Library",
            major: "Computer Science",
            universityYear: 2,
            isInvisible: false,
            lastKnownLat: nil,
            lastKnownLng: nil
        )

        // If email provided and doesn't match mock, optionally derive display name from email
        if let providedEmail = email, providedEmail != profile.email {
            profile.email = providedEmail
            if let derived = deriveDisplayName(from: providedEmail) {
                profile.displayName = derived
            }
        }

        return profile
    }

    private func deriveDisplayName(from email: String) -> String? {
        guard let localPart = email.split(separator: "@").first, !localPart.isEmpty else { return nil }
        return localPart.replacingOccurrences(of: ".", with: " ")
            .split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}
