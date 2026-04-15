//  FriendRequestService.swift
//  studyconnect
//
//

import Foundation
import Supabase
internal import PostgREST

class FriendRequestService {

    /// Sends a friend request by inserting a row into `friends`.
    /// Single row with status='pending'. Receiver must accept.
    func sendRequest(toFriendId: UUID) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendId = toFriendId.uuidString.lowercased()

        do {
            try await client
                .from("friends")
                .insert([
                    "user_id": myId,
                    "friend_id": friendId,
                    "status": "pending"
                ])
                .execute()
            print("✅ Friend request sent to \(friendId)")
        } catch {
            print("❌ Failed to send friend request: \(error.localizedDescription)")
        }
    }

    /// Fetches incoming friend requests where the current user is `friend_id`
    /// and `status` is still pending.
    func getIncomingRequests() async -> [FriendRequest] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()

        do {
            // Get pending rows where I'm the receiver
            let result = try await client
                .from("friends")
                .select()
                .eq("friend_id", value: myId)
                .eq("status", value: "pending")
                .execute()

            let rows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []

            let senderIds = rows.compactMap { $0["user_id"] as? String }
            guard !senderIds.isEmpty else { return [] }

            // Fetch sender profiles
            let usersResult = try await client
                .from("users")
                .select()
                .in("user_id", values: senderIds)
                .execute()
            let userRows = (try? JSONSerialization.jsonObject(with: usersResult.data) as? [[String: Any]]) ?? []

            let profileMap = Dictionary(uniqueKeysWithValues: userRows.compactMap { row -> (String, UserProfile)? in
                guard let idStr = row["user_id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let displayName = row["display_name"] as? String,
                      let email = row["email"] as? String else { return nil }
                return (idStr, UserProfile(userId: id, displayName: displayName, email: email))
            })

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            return rows.compactMap { row -> FriendRequest? in
                guard let uid = row["user_id"] as? String,
                      let fid = row["friend_id"] as? String,
                      let statusStr = row["status"] as? String,
                      let createdStr = row["created_at"] as? String,
                      let userId = UUID(uuidString: uid),
                      let friendId = UUID(uuidString: fid),
                      let createdAt = dateFormatter.date(from: createdStr) else { return nil }

                var request = FriendRequest(
                    userId: userId,
                    friendId: friendId,
                    status: FriendRequest.Status(rawValue: statusStr) ?? .pending,
                    createdAt: createdAt
                )
                request.fromUser = profileMap[uid]
                return request
            }
        } catch {
            print("❌ Failed to fetch incoming requests: \(error.localizedDescription)")
            return []
        }
    }

    /// Accepts a friend request: updates the sender's row to 'accepted' and
    /// inserts the reverse row (me → sender, 'accepted') so both users see each other.
    func acceptRequest(fromUserId: UUID) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let senderId = fromUserId.uuidString.lowercased()

        do {
            // 1. Update the sender's pending row to accepted
            try await client
                .from("friends")
                .update(["status": "accepted"])
                .eq("user_id", value: senderId)
                .eq("friend_id", value: myId)
                .execute()

            // 2. Insert the reverse row (me → sender) as accepted
            try await client
                .from("friends")
                .upsert([
                    ["user_id": myId, "friend_id": senderId, "status": "accepted"]
                ])
                .execute()

            print("✅ Accepted friend request from \(senderId)")
        } catch {
            print("❌ Failed to accept friend request: \(error.localizedDescription)")
        }
    }

    /// Rejects a friend request by deleting the row entirely.
    func rejectRequest(fromUserId: UUID) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let senderId = fromUserId.uuidString.lowercased()

        do {
            try await client
                .from("friends")
                .delete()
                .eq("user_id", value: senderId)
                .eq("friend_id", value: myId)
                .execute()
            print("✅ Rejected friend request from \(senderId)")
        } catch {
            print("❌ Failed to reject friend request: \(error.localizedDescription)")
        }
    }
}
