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

    // Fetch friends list from Supabase
    func getFriendsList() async -> [UserProfile] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        
        do {
            // 1a. Rows where I'm user_id (I sent the request, both accepted)
            let sentResult = try await client
                .from("friends")
                .select()
                .eq("user_id", value: myId)
                .eq("user_status", value: "accepted")
                .eq("friend_status", value: "accepted")
                .execute()
            let sentRows = (try? JSONSerialization.jsonObject(with: sentResult.data) as? [[String: Any]]) ?? []
            let sentFriendIds = sentRows.compactMap { $0["friend_id"] as? String }

            // 1b. Rows where I'm friend_id (I received the request, both accepted)
            let recvResult = try await client
                .from("friends")
                .select()
                .eq("friend_id", value: myId)
                .eq("user_status", value: "accepted")
                .eq("friend_status", value: "accepted")
                .execute()
            let recvRows = (try? JSONSerialization.jsonObject(with: recvResult.data) as? [[String: Any]]) ?? []
            let recvFriendIds = recvRows.compactMap { $0["user_id"] as? String }

            let allFriendIds = Array(Set(sentFriendIds + recvFriendIds))
            guard !allFriendIds.isEmpty else { return [] }
            
            // 2. Fetch friend profiles from the users table
            let usersResult = try await client
                .from("users")
                .select()
                .in("user_id", values: allFriendIds)
                .execute()
                
            let userRows = (try? JSONSerialization.jsonObject(with: usersResult.data) as? [[String: Any]]) ?? []
            
            return userRows.compactMap { row -> UserProfile? in
                guard let idStr = row["user_id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let displayName = row["display_name"] as? String,
                      let email = row["email"] as? String else { return nil }
                      
                return UserProfile(userId: id, displayName: displayName, email: email)
            }
        } catch {
            print("❌ Failed to fetch friends list: \(error.localizedDescription)")
            return []
        }
    }

    // Add a friend by sending a friend request
    func addFriend(id: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendId = id.lowercased()
        
        do {
            // Insert a friend request: sender is auto-accepted, receiver is pending
            try await client
                .from("friends")
                .upsert([
                    ["user_id": myId, "friend_id": friendId,
                     "user_status": "accepted", "friend_status": "pending"]
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
}
