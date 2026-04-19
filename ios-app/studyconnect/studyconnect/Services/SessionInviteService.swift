//
//  SessionInviteService.swift
//  studyconnect
//
//

import Foundation
import Auth
internal import PostgREST
import Supabase

/// Extra session details that aren't yet returned by the real backend.
/// Backend partner: replace `fetchSessionExtrasStub` with a real fetch that joins
/// the study_spots table for the address and pulls the Google Meet link from the
/// Calendar event created during session creation.
struct SessionExtras {
    let locationName: String?
    let locationAddress: String?
    let meetingLink: String?
}

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

        // 4. Look up study spot names for any sessions that reference one.
        let studySpotIds = Array(Set(sessionRows.compactMap { $0["study_spot_id"] as? String }))
        var spotNames: [String: String] = [:]
        if !studySpotIds.isEmpty {
            do {
                let result = try await client
                    .from("study_spots")
                    .select("spot_id,name")
                    .in("spot_id", values: studySpotIds)
                    .execute()
                let rows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
                for row in rows {
                    guard let id = row["spot_id"] as? String,
                          let name = row["name"] as? String else { continue }
                    spotNames[id] = name
                }
            } catch {
                print("❌ Failed to fetch study spot names: \(error.localizedDescription)")
            }
        }

        // 5. Build SessionInvite objects (id = session UUID for accept/decline).
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
            let title = session["title"] as? String
            let description = session["description"] as? String
            let spotName = (session["study_spot_id"] as? String).flatMap { spotNames[$0] }

            let extras = fetchSessionExtrasStub(sessionId: sessionUUID, studySpotName: spotName)

            invites.append(SessionInvite(
                id: sessionUUID,
                fromUser: creator,
                startTime: startsAt,
                endTime: endsAt,
                createdAt: createdAt,
                title: title,
                description: description,
                locationName: extras.locationName,
                locationAddress: extras.locationAddress,
                meetingLink: extras.meetingLink
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

    // MARK: - Stubbed extras

    /// STUB — backend partner: replace with a real fetch that returns location address
    /// and Google Meet link per session (see STUBS_BACKEND_HANDOFF.md).
    /// Produces deterministic example data keyed off the session UUID so the UI stays stable.
    private func fetchSessionExtrasStub(sessionId: UUID, studySpotName: String?) -> SessionExtras {
        let samples: [SessionExtras] = [
            SessionExtras(
                locationName: studySpotName ?? "Shapiro Undergraduate Library",
                locationAddress: "919 S University Ave, Ann Arbor, MI 48109",
                meetingLink: "https://meet.google.com/abc-defg-hij"
            ),
            SessionExtras(
                locationName: studySpotName ?? "Hatcher Graduate Library",
                locationAddress: "913 S University Ave, Ann Arbor, MI 48109",
                meetingLink: "https://meet.google.com/xyz-1234-uvw"
            ),
            SessionExtras(
                locationName: studySpotName ?? "Duderstadt Center",
                locationAddress: "2281 Bonisteel Blvd, Ann Arbor, MI 48109",
                meetingLink: "https://meet.google.com/mno-5678-pqr"
            ),
        ]
        let bytes = withUnsafeBytes(of: sessionId.uuid) { Array($0) }
        let idx = Int(bytes.first ?? 0) % samples.count
        return samples[idx]
    }
}
