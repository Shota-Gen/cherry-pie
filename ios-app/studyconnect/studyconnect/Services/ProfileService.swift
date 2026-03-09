//
//  ProfileService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation

class ProfileService {
    // STUB: Fetch current user's profile
    func fetchProfile() -> UserProfile {
        return UserProfile(
            displayName: "Jawad",
            bio: "Looking for focused study sessions.",
            major: "Computer Science",
            graduationYear: "2026"
        )
    }

    // STUB: Update current user's profile
    func updateProfile(_ profile: UserProfile) {
        print("Updating profile: \(profile)")
        // TODO: Implement actual API call
    }
}
