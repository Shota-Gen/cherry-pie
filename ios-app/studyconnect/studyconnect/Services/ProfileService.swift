//
//  ProfileService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation

class ProfileService {
    // STUB: Fetch profile. Display name fallback: API → derived from email → blank.
    func fetchProfile(email: String?) -> UserProfile {
        var profile = fetchProfileFromAPIStub() ?? UserProfile.blank(email: email ?? "")
        if profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.displayName = email.flatMap { deriveDisplayName(from: $0) } ?? ""
        }
        if let email { profile.email = email }
        return profile
    }

    // STUB: Update current user's profile
    func updateProfile(_ profile: UserProfile) {
        print("Updating profile: \(profile)")
        // TODO: Implement actual API call
    }

    // STUB: Replace with real Supabase fetch.
    private func fetchProfileFromAPIStub() -> UserProfile? {
        return nil
    }

    private func deriveDisplayName(from email: String) -> String? {
        guard let localPart = email.split(separator: "@").first, !localPart.isEmpty else { return nil }
        return localPart.replacingOccurrences(of: ".", with: " ")
            .split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}
