//
//  FriendsService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import Foundation
import Auth
import Supabase
internal import PostgREST

class FriendsService {

    // Fetch friends list from Supabase (dual-entry model: only check user_id = me)
    func getFriendsList() async -> [UserProfile] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        
        do {
            // Single-direction query: rows where I'm user_id and status is accepted
            let result = try await client
                .from("friends")
                .select()
                .eq("user_id", value: myId)
                .eq("status", value: "accepted")
                .execute()
            let rows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
            let allFriendIds = rows.compactMap { $0["friend_id"] as? String }
            guard !allFriendIds.isEmpty else { return [] }
            
            // 2. Fetch friend profiles from the users table
            let usersResult = try await client
                .from("users")
                .select()
                .in("user_id", values: allFriendIds)
                .execute()
                
            let userRows = (try? JSONSerialization.jsonObject(with: usersResult.data) as? [[String: Any]]) ?? []

            // 3. Fetch which friends are currently in a study spot (PostGIS-based, always accurate)
            let spotResult = try await client
                .rpc("get_users_in_study_spots", params: ["current_user_id": userId])
                .execute()
            let spotRows = (try? JSONSerialization.jsonObject(with: spotResult.data) as? [[String: Any]]) ?? []
            let spotMap = Dictionary(uniqueKeysWithValues: spotRows.compactMap { row -> (String, String)? in
                guard let id = row["user_id"] as? String,
                      let spot = row["spot_name"] as? String else { return nil }
                return (id, spot)
            })

            return userRows.compactMap { row -> UserProfile? in
                guard let idStr = row["user_id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let displayName = row["display_name"] as? String,
                      let email = row["email"] as? String else { return nil }

                var profile = UserProfile(userId: id, displayName: displayName, email: email)
                profile.studySpot = spotMap[idStr] ?? ""
                return profile
            }
        } catch {
            print("❌ Failed to fetch friends list: \(error.localizedDescription)")
            return []
        }
    }

    // Add a friend by sending a friend request (single pending row)
    func addFriend(id: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendId = id.lowercased()
        
        do {
            // Insert a pending friend request (single row, receiver must accept)
            try await client
                .from("friends")
                .upsert([
                    ["user_id": myId, "friend_id": friendId, "status": "pending"]
                ])
                .execute()
            print("✅ Friend request sent to: \(id)")
        } catch {
            print("❌ Failed to add friend: \(error.localizedDescription)")
        }
    }

    // Delete a friend (removes the friendship row regardless of direction)
    func deleteFriends(ids: Set<UUID>) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        guard !ids.isEmpty else { return }
        
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendIdsGroup = ids.map { $0.uuidString.lowercased() }
        
        do {
            // Delete rows where I'm user_id and they're friend_id
            try await client
                .from("friends")
                .delete()
                .eq("user_id", value: myId)
                .in("friend_id", values: friendIdsGroup)
                .execute()
            
            // Delete rows where they're user_id and I'm friend_id
            try await client
                .from("friends")
                .delete()
                .in("user_id", values: friendIdsGroup)
                .eq("friend_id", value: myId)
                .execute()
                
            print("✅ Deleted friendships with IDs: \(friendIdsGroup)")
        } catch {
            print("❌ Failed to delete friends: \(error.localizedDescription)")
        }
    }

    // Returns suggested friends to invite to a session.
    func getSuggestedFriends() async -> [UserProfile] {
        return await getFriendsList()
    }

    // Returns only visible friends who are in the same study spot as the current user.
    func getFriendsInSameStudySpot() async -> [UserProfile] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }
        let client = SupabaseManager.shared.client

        do {
            let result = try await client
                .rpc("get_friends_in_same_study_spot", params: ["current_user_id": userId])
                .execute()
            print(result.data)
            let rows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []

            return rows.compactMap { row -> UserProfile? in
                guard let idStr = row["user_id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let displayName = row["display_name"] as? String else { return nil }

                return UserProfile(
                    userId: id,
                    displayName: displayName,
                    email: "",
                    lastKnownLat: row["last_known_lat"] as? Double,
                    lastKnownLng: row["last_known_lng"] as? Double,
                    altitude: row["altitude"] as? Double ?? 0
                )
            }
        } catch {
            print("❌ Failed to fetch friends in same study spot: \(error.localizedDescription)")
            return []
        }
    }
}
