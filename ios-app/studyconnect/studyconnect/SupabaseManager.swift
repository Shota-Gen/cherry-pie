import Foundation
import Supabase
import UIKit
import SwiftUI
import Observation
import GoogleSignIn
import CryptoKit

@Observable
class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Always use production Supabase for testing on simulator
    private static let supabaseURL = URL(string: "https://gnupzytcsswejfvtifik.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdudXB6eXRjc3N3ZWpmdnRpZmlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MjE5NTUsImV4cCI6MjA4NzM5Nzk1NX0.r3yj0WuNskL1qHVwKyvBl3OXZyociZYpBtkKzpeOaz8"
    
    let client = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
    
    var session: Session? = nil
    
    init() {
        Task {
            do {
                let sess = try await client.auth.session
                self.session = sess
                await ensureUserRowExists()
            } catch {
                print("No active session found")
            }
        }
    }

    func signInWithGoogle(presenting presentingVC: UIViewController) async {
        do {
            // 1. Generate a random 'nonce' string
            let rawNonce = String.randomNonce()
            let hashedNonce = sha256(rawNonce)

            // Request calendar scopes for Smart Scheduler + GCal invites
            let calendarScopes = [
                "https://www.googleapis.com/auth/calendar.freebusy",
                "https://www.googleapis.com/auth/calendar.events"
            ]

            // Present Google Sign-In (API runs on main actor)
            let gidResult = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingVC,
                hint: nil,
                additionalScopes: calendarScopes,
                nonce: hashedNonce
            )

            guard let idToken = gidResult.user.idToken?.tokenString else { return }
            let accessToken = gidResult.user.accessToken.tokenString

            // 2. Exchange tokens with Supabase (no main actor required)
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken,
                    nonce: rawNonce
                )
            )

            // 3. Publish session change without forcing MainActor (Observation can coalesce updates)
            self.session = session
            print("✅ Logged in: \(session.user.email ?? "Unknown")")
            let nameHint = gidResult.user.profile?.name
            await ensureUserRowExists(displayNameHint: nameHint)

            // 4. Store Google tokens for Smart Scheduler (calendar access)
            let googleEmail = gidResult.user.profile?.email ?? session.user.email ?? ""
            let serverAuthCode = gidResult.serverAuthCode ?? ""
            if serverAuthCode.isEmpty {
                print("⚠️ No serverAuthCode returned — GIDServerClientID may be missing from Info.plist")
            }
            await storeGoogleCalendarToken(
                userId: session.user.id,
                serverAuthCode: serverAuthCode,
                accessToken: accessToken,
                googleEmail: googleEmail
            )

        } catch {
            print("❌ Login failed: \(error.localizedDescription)")
        }
    }

    /// Store the Google OAuth tokens on the backend for offline FreeBusy access.
    private func storeGoogleCalendarToken(userId: UUID, serverAuthCode: String, accessToken: String, googleEmail: String) async {
        do {
            let service = SessionService()
            try await service.storeGoogleToken(
                userId: userId,
                serverAuthCode: serverAuthCode,
                accessToken: accessToken,
                googleEmail: googleEmail
            )
            print("✅ Google Calendar token stored for Smart Scheduler")
        } catch {
            // Non-critical — Smart Scheduler will still work with fallback
            print("⚠️ Could not store Google Calendar token: \(error.localizedDescription)")
        }
    }

    func linkDeviceToUser() async {
        await ensureUserRowExists()
    }

    func ensureUserRowExists(displayNameHint: String? = nil) async {
        let userId = self.session?.user.id
        let email = self.session?.user.email
        guard let userId else {
            return
        }

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_ios_device"

        do {
            // 1. See if a row already exists.
            if var existing: SupabaseUserRow = try? await client
                .from("users")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            {
                var update: [String: AnyEncodable] = [
                    "device_id": AnyEncodable(deviceID)
                ]

                // One-time upgrade: if we have a Google name and the current display_name
                // is empty or just the email-derived default, replace it with the Google name.
                if let googleName = displayNameHint, !googleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let currentName = (existing.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let emailDerived = email.flatMap { ProfileService.deriveDisplayName(from: $0) } ?? ""

                    if currentName.isEmpty || currentName.caseInsensitiveCompare(emailDerived) == .orderedSame {
                        update["display_name"] = AnyEncodable(googleName)
                    }
                }

                try await client
                    .from("users")
                    .update(update)
                    .eq("user_id", value: userId)
                    .execute()
                print("✅ Linked Device ID: \(deviceID)")
                return
            }

            // 2. No existing row: create one, preferring Google name when available
            let displayName = displayNameHint
                ?? email.flatMap { ProfileService.deriveDisplayName(from: $0) }

            let row = SupabaseUserRow(
                userId: userId,
                displayName: displayName,
                email: email,
                deviceId: deviceID,
                isInvisible: nil,
                lastKnownLat: nil,
                lastKnownLng: nil,
                currentFloor: nil,
                createdAt: nil,
                profileImage: nil,
                studySpot: nil,
                major: nil,
                universityYear: nil
            )

            try await client
                .from("users")
                .insert(row)
                .execute()
            print("✅ Created user row and linked Device ID: \(deviceID)")
        } catch {
            print("❌ ensureUserRowExists failed: \(error.localizedDescription)")
        }
    }
    
    func updateLocation(latitude: Double, longitude: Double) async {
        let userId = self.session?.user.id
        guard let userId else { return }

        do {
            let updateData: [String: AnyEncodable] = [
                "last_known_lat": AnyEncodable(latitude),
                "last_known_lng": AnyEncodable(longitude)
            ]

            try await client
                .from("users")
                .update(updateData)
                .eq("user_id", value: userId)
                .execute()

            print("Location updated: \(latitude), \(longitude)")
        } catch {
            print("Location update failed: \(error.localizedDescription)")
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("❌ Supabase sign out failed: \(error.localizedDescription)")
        }

        GIDSignIn.sharedInstance.signOut()
        self.session = nil

        print("✅ Signed out")
    }
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

extension String {
    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

// Helper to handle mixed types for Supabase updates ? .. not tested
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Environment Integration

private struct SupabaseManagerKey: EnvironmentKey {
    static let defaultValue: SupabaseManager = .shared
}

extension EnvironmentValues {
    var supabaseManager: SupabaseManager {
        get { self[SupabaseManagerKey.self] }
        set { self[SupabaseManagerKey.self] = newValue }
    }
}

