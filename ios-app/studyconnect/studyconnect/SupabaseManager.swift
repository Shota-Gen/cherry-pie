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
    
    #if DEBUG
    // Local Supabase (via `supabase start`)
    private static let supabaseURL = URL(string: "http://localhost:54321")!
    private static let supabaseKey = "sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz"
    #else
    // Production Supabase
    private static let supabaseURL = URL(string: "https://gnupzytcsswejfvtifik.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdudXB6eXRjc3N3ZWpmdnRpZmlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MjE5NTUsImV4cCI6MjA4NzM5Nzk1NX0.r3yj0WuNskL1qHVwKyvBl3OXZyociZYpBtkKzpeOaz8"
    #endif
    
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
                self.session = try await client.auth.session
            } catch {
                print("No active session found")
            }
        }
    }

    @MainActor
    func signInWithGoogle() async {
        do {
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else { return }

            // 1. Generate a random 'nonce' string
            let rawNonce = String.randomNonce()
            let hashedNonce = sha256(rawNonce)

            // 2. Pass the HASHED nonce to Google
            let gidResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC, hint: nil, additionalScopes: nil, nonce: hashedNonce)
            
            guard let idToken = gidResult.user.idToken?.tokenString else { return }
            let accessToken = gidResult.user.accessToken.tokenString

            // 3. Pass the RAW nonce to Supabase so it can verify the token
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken,
                    nonce: rawNonce
                )
            )
            
            self.session = session
            print("✅ Logged in: \(self.session?.user.email ?? "Unknown")")
            await linkDeviceToUser()
            
        } catch {
            print("❌ Login failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    func linkDeviceToUser() async {
        guard let userId = session?.user.id else {
            print("❌ No user logged in")
            return
        }
        
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_ios_device"
        
        do {
            try await client
                .from("users")
                .update(["device_id": deviceID])
                .eq("user_id", value: userId)
                .execute()
            print("✅ Linked Device ID: \(deviceID)")
        } catch {
            print("❌ Update failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func updateLocation(latitude: Double, longitude: Double) async {
        guard let userId = session?.user.id else { return }
        
        do {
            // Removed "last_seen" to match the actual database schema
            let updateData: [String: AnyEncodable] = [
                "last_known_lat": AnyEncodable(latitude),
                "last_known_lng": AnyEncodable(longitude)
                // possible to add a last-seen field to supabase, so we
                // can display elapsed time (ex: last seen location from 20 min ago)
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

    @MainActor
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("❌ Supabase sign out failed: \(error.localizedDescription)")
        }

        GIDSignIn.sharedInstance.signOut()
        session = nil
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




