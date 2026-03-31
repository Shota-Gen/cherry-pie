//
//  UserProfile.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation

/// Core domain model representing a user.  Maps to the `public.users` Supabase table.
/// Used throughout the app for friends lists, profile display, session invites, etc.
/// `distanceMiles` is a UI-only field (not persisted) used for sorting friends by proximity.
struct UserProfile: Identifiable, Codable, Hashable {
    // Mirrors public.users table in Supabase.
    var userId: UUID
    var displayName: String
    var email: String
    var profileImage: String = ""
    var studySpot: String = ""
    var major: String = ""
    var universityYear: Int? = nil
    var deviceId: String? = nil
    var isInvisible: Bool = false
    var lastKnownLat: Double? = nil
    var lastKnownLng: Double? = nil
    var currentFloor: Int = 1
    var createdAt: Date? = nil
    var distanceMiles: Double? = nil   // UI-only, for friends list sorting

    var id: UUID { userId }

    /// Returns displayName if non-empty, otherwise falls back to email.
    var displayTitle: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? email : displayName
    }

    /// Factory for empty/placeholder profiles (used during loading states).
    static func blank(email: String = "") -> UserProfile {
        UserProfile(userId: UUID(), displayName: "", email: email)
    }
}
