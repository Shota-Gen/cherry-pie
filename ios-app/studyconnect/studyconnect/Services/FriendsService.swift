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

/// Handles all friend-related operations against the Supabase `friends` and
/// `users` tables.  No @Observable — stateless service instantiated as @State
/// inside views that need it.
class FriendsService {

    /// Fetches the signed-in user’s friends list.
    /// Two-step query: (1) get friend IDs from `friends` table, (2) fetch
    /// their profile data from `users` table.
    func getFriendsList() async -> [UserProfile] {
        guard let userId = SupabaseManager.shared.session?.user.id else { return [] }
        let client = SupabaseManager.shared.client
        
        do {
            // 1. Get friend IDs from the friends table
            let result = try await client
                .from("friends")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                
            let friendRows = (try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]) ?? []
            let friendIds = friendRows.compactMap { $0["friend_id"] as? String }
            
            guard !friendIds.isEmpty else { return [] }
            
            // 2. Fetch friend profiles from the users table
            let usersResult = try await client
                .from("users")
                .select()
                .in("user_id", values: friendIds)
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

    /// Creates a bidirectional friendship by upserting two rows in the `friends` table
    /// (me→them and them→me).  Uses upsert to avoid duplicate key errors.
    func addFriend(id: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendId = id.lowercased()
        
        do {
            // Insert both directions: me→them and them→me
            try await client
                .from("friends")
                .upsert([
                    ["user_id": myId, "friend_id": friendId],
                    ["user_id": friendId, "friend_id": myId]
                ])
                .execute()
            print("✅ Mutual friendship created with: \(id)")
        } catch {
            print("❌ Failed to add friend: \(error.localizedDescription)")
        }
    }

    /// Removes both directions of mutual friendships for the given set of friend IDs.
    func deleteFriends(ids: Set<UUID>) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        guard !ids.isEmpty else { return }
        
        let client = SupabaseManager.shared.client
        let myId = userId.uuidString.lowercased()
        let friendIdsGroup = ids.map { $0.uuidString.lowercased() }
        
        do {
            // Delete me→them
            try await client
                .from("friends")
                .delete()
                .eq("user_id", value: myId)
                .in("friend_id", values: friendIdsGroup)
                .execute()
            
            // Delete them→me
            try await client
                .from("friends")
                .delete()
                .in("user_id", values: friendIdsGroup)
                .eq("friend_id", value: myId)
                .execute()
                
            print("✅ Deleted mutual friendships with IDs: \(friendIdsGroup)")
        } catch {
            print("❌ Failed to delete friends: \(error.localizedDescription)")
        }
    }

    /// Returns friends to suggest for session invitations.
    /// STUB: currently just delegates to getFriendsList(); will be replaced
    /// with a real suggestion algorithm (e.g., nearby users, frequent partners).
    func getSuggestedFriends() async -> [UserProfile] {
        return await getFriendsList()
    }
}
