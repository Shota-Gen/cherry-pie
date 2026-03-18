//
//  ProfileService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/9/26.
//

import Foundation
import Supabase

class ProfileService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchMyProfile(userId: UUID, fallbackEmail: String? = nil) async throws -> UserProfile {
        if let row = try await fetchUserRow(userId: userId) {
            var profile = row.toUserProfile()
            if profile.email.isEmpty {
                profile.email = fallbackEmail ?? profile.email
            }
            return profile
        }

        // Row missing: create a minimal row and refetch
        try await upsertUserRow(
            SupabaseUserRow(
                userId: userId,
                displayName: fallbackEmail.flatMap { Self.deriveDisplayName(from: $0) },
                email: fallbackEmail,
                deviceId: nil,
                isInvisible: false,
                lastKnownLat: nil,
                lastKnownLng: nil,
                currentFloor: 1,
                createdAt: nil,
                profileImage: nil,
                studySpot: nil,
                major: nil,
                universityYear: nil
            )
        )

        guard let row = try await fetchUserRow(userId: userId) else {
            throw ProfileServiceError.profileRowMissingAfterUpsert
        }
        return row.toUserProfile()
    }

    func updateProfile(_ profile: UserProfile) async throws {
        let updateData: [String: AnyEncodable] = [
            "display_name": AnyEncodable(profile.displayName),
            "major": AnyEncodable(profile.major),
            "university_year": AnyEncodable(profile.universityYear),
            "profile_image": AnyEncodable(profile.profileImage),
            "study_spot": AnyEncodable(profile.studySpot)
        ]

        try await client
            .from("users")
            .update(updateData)
            .eq("user_id", value: profile.userId)
            .execute()
    }

    func updateGhostMode(enabled: Bool, userId: UUID) async throws {
        try await client
            .from("users")
            .update(["is_invisible": enabled])
            .eq("user_id", value: userId)
            .execute()
    }

    // Not yet implemented in schema/UI, leaving as a no-op for now.
    func updatePushNotifications(enabled: Bool, userId: UUID) async {
        _ = (enabled, userId)
    }

    private func fetchUserRow(userId: UUID) async throws -> SupabaseUserRow? {
        do {
            return try await client
                .from("users")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            // Supabase Swift throws for 0-row `.single()` queries.
            // Treat that case as "missing row" and let caller decide to upsert.
            if Self.looksLikeNoRowError(error) {
                return nil
            }
            throw error
        }
    }

    private func upsertUserRow(_ row: SupabaseUserRow) async throws {
        try await client
            .from("users")
            .upsert(row)
            .execute()
    }

    static func deriveDisplayName(from email: String) -> String? {
        guard let localPart = email.split(separator: "@").first, !localPart.isEmpty else { return nil }
        return localPart.replacingOccurrences(of: ".", with: " ")
            .split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }

    private static func looksLikeNoRowError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        // Best-effort match across PostgREST/Supabase error variants
        return message.contains("json") && message.contains("0 rows")
            || message.contains("results contain 0 rows")
            || message.contains("pgrst116")
    }
}

enum ProfileServiceError: Error {
    case profileRowMissingAfterUpsert
}
