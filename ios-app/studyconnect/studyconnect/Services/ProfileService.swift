//
//  ProfileService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation

class ProfileService {
    // STUB: Fetch current user's profile with fallback display name logic.
    // 1) Use API displayName if present.
    // 2) Else derive from logged-in email local-part.
    // 3) Else keep displayName blank.
    // Other fields stay blank unless API provides them.
    func fetchProfile(email: String?) -> UserProfile {
        let apiProfile = fetchProfileFromAPIStub()

        let displayName: String
        if let apiDisplayName = apiProfile?.displayName,
           !apiDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = apiDisplayName
        } else if let email,
                  let emailDisplayName = deriveDisplayName(from: email),
                  !emailDisplayName.isEmpty {
            displayName = emailDisplayName
        } else {
            displayName = ""
        }

        return UserProfile(
            displayName: displayName,
            bio: apiProfile?.bio ?? "",
            major: apiProfile?.major ?? "",
            graduationYear: apiProfile?.graduationYear ?? ""
        )
    }

    // STUB: Update current user's profile
    func updateProfile(_ profile: UserProfile) {
        print("Updating profile: \(profile)")
        // TODO: Implement actual API call
    }

    // STUB: Replace with real API call that fetches profile from backend.
    private func fetchProfileFromAPIStub() -> UserProfile? {
        return UserProfile(
            displayName: "",
            bio: "",
            major: "",
            graduationYear: ""
        )
    }

    private func deriveDisplayName(from email: String) -> String? {
        let parts = email.split(separator: "@")
        guard let localPart = parts.first, !localPart.isEmpty else { return nil }

        let normalized = localPart.replacingOccurrences(of: ".", with: " ")
        let words = normalized
            .split(separator: " ")
            .map { $0.capitalized }

        return words.joined(separator: " ")
    }
}
