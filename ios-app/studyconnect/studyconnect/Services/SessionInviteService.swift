//
//  SessionInviteService.swift
//  studyconnect
//
//

import Foundation
import Auth
internal import PostgREST
import Supabase

class SessionInviteService {

    #if DEBUG && targetEnvironment(simulator)
    private let baseURL = "http://localhost:8080"
    #else
    private let baseURL = "https://cherry-pie-production.up.railway.app"
    #endif

    /// Fetch pending session invites for the signed-in user.
    /// Queries Supabase `session_members` for rows with status 'pending',
    /// then fetches associated session details and creator profiles.
    func getPendingInvites() async -> [SessionInvite] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }

        let client = SupabaseManager.shared.client

        // 1. Find session_member rows where the current user is pending.
        let memberRows: [[String: Any]]
        do {
            let result = try await client
                .from("session_members")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()
            memberRows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
        } catch {
            print("❌ Failed to fetch pending memberships: \(error.localizedDescription)")
            return []
        }

        guard !memberRows.isEmpty else { return [] }

        let sessionIds = memberRows.compactMap { $0["session_id"] as? String }

        // 2. Fetch corresponding sessions.
        let sessionRows: [[String: Any]]
        do {
            let result = try await client
                .from("sessions")
                .select()
                .in("session_id", values: sessionIds)
                .execute()
            sessionRows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
        } catch {
            print("❌ Failed to fetch sessions: \(error.localizedDescription)")
            return []
        }

        // 3. Collect creator IDs and fetch their profiles.
        let creatorIds = Array(Set(sessionRows.compactMap { $0["created_by"] as? String }))
        var creatorsMap: [String: UserProfile] = [:]
        if !creatorIds.isEmpty {
            do {
                let result = try await client
                    .from("users")
                    .select()
                    .in("user_id", values: creatorIds)
                    .execute()
                let userRows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
                for row in userRows {
                    guard let uid = row["user_id"] as? String else { continue }
                    creatorsMap[uid] = UserProfile(
                        userId: UUID(uuidString: uid) ?? UUID(),
                        displayName: row["display_name"] as? String ?? "",
                        email: row["email"] as? String ?? ""
                    )
                }
            } catch {
                print("❌ Failed to fetch creator profiles: \(error.localizedDescription)")
            }
        }

        // 4. Build SessionInvite objects (id = session UUID for accept/decline).
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ value: Any?) -> Date? {
            guard let str = value as? String else { return nil }
            return dateFormatter.date(from: str) ?? fallbackFormatter.date(from: str)
        }

        var invites: [SessionInvite] = []
        for session in sessionRows {
            guard let sessionIdStr = session["session_id"] as? String,
                  let sessionUUID = UUID(uuidString: sessionIdStr),
                  let startsAt = parseDate(session["starts_at"]),
                  let endsAt = parseDate(session["ends_at"]) else { continue }

            let creatorId = session["created_by"] as? String ?? ""
            let creator = creatorsMap[creatorId] ?? UserProfile(userId: UUID(), displayName: "Unknown", email: "")

            let createdAt = parseDate(session["created_at"]) ?? Date()

            invites.append(SessionInvite(
                id: sessionUUID,
                fromUser: creator,
                startTime: startsAt,
                endTime: endsAt,
                createdAt: createdAt
            ))
        }

        return invites
    }

    /// Accept a session invite by calling the backend respond endpoint.
    func acceptInvite(inviteId: UUID) {
        respondToInvite(sessionId: inviteId, action: "accepted")
    }

    /// Decline a session invite by calling the backend respond endpoint.
    func declineInvite(inviteId: UUID) {
        respondToInvite(sessionId: inviteId, action: "declined")
    }

    private func respondToInvite(sessionId: UUID, action: String) {
        guard let userId = SupabaseManager.shared.session?.user.id else {
            print("❌ No signed-in user for invite response")
            return
        }

        Task {
            do {
                guard let url = URL(string: "\(baseURL)/sessions/\(sessionId.uuidString)/respond") else {
                    print("❌ Failed to build respond URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: String] = [
                    "user_id": userId.uuidString,
                    "action": action
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ Invite \(action) successfully")
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("❌ Invite response failed with status \(statusCode)")
                }
            } catch {
                print("❌ Invite response error: \(error.localizedDescription)")
            }
        }
    }
}
