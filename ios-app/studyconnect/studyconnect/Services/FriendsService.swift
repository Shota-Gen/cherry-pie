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

    // Add a friend by ID
    func addFriend(id: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        let client = SupabaseManager.shared.client
        
        do {
            try await client
                .from("friends")
                .insert([
                    "user_id": userId.uuidString.lowercased(),
                    "friend_id": id.lowercased() // Assuming input id is also a UUID string
                ])
                .execute()
            print("✅ Friend added: \(id)")
        } catch {
            print("❌ Failed to add friend: \(error.localizedDescription)")
        }
    }

    // Delete a friend
    func deleteFriends(ids: Set<UUID>) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        guard !ids.isEmpty else { return }
        
        let client = SupabaseManager.shared.client
        let friendIdsGroup = ids.map { $0.uuidString.lowercased() }
        
        do {
            try await client
                .from("friends")
                .delete()
                .eq("user_id", value: userId.uuidString.lowercased())
                .in("friend_id", values: friendIdsGroup)
                .execute()
                
            print("✅ Deleted friends with IDs: \(friendIdsGroup)")
        } catch {
            print("❌ Failed to delete friends: \(error.localizedDescription)")
        }
    }

    // Returns suggested friends to invite to a session.
    func getSuggestedFriends() async -> [UserProfile] {
        return await getFriendsList()
    }
}
