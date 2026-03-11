//
//  FriendsService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import Foundation

private var stubFriends: [UserProfile] = [
    UserProfile(userId: UUID(), displayName: "Alice Johnson",  email: "alice@umich.edu", studySpot: "Engineering Building", distanceMiles: 0.2),
    UserProfile(userId: UUID(), displayName: "Bob Smith",      email: "bob@umich.edu",   studySpot: "Library",             distanceMiles: 0.5),
    UserProfile(userId: UUID(), displayName: "Carol Davis",    email: "carol@umich.edu", studySpot: "Student Center",      distanceMiles: 1.2),
    UserProfile(userId: UUID(), displayName: "David Wilson",   email: "david@umich.edu", studySpot: "Dining Hall",         distanceMiles: 1.8),
    UserProfile(userId: UUID(), displayName: "Emma Brown",     email: "emma@umich.edu",  studySpot: "Gym",                 distanceMiles: 0.3)
]

class FriendsService {

    // STUB: Fetch friends list
    func getFriendsList() -> [UserProfile] {
        return stubFriends
        // TODO: Implement actual API call to fetch friends list
    }

    // STUB: Add a friend by ID.
    // TODO: Decide whether to use user ID or email for friend lookup before hooking to backend.
    func addFriend(id: String) {
        print("Adding friend with ID: \(id)")
        // TODO: Implement actual API call
    }

    // STUB: Delete a friend
    func deleteFriends(ids: Set<UUID>) {
            stubFriends.removeAll { ids.contains($0.userId) }
            print("Deleting friends with IDs: \(ids)")
            // TODO: Implement actual API call
        }

    // STUB: Returns suggested friends to invite to a session.
    func getSuggestedFriends() -> [UserProfile] {
        return getFriendsList()
        // TODO: Replace with real suggestion algorithm (e.g. nearby, frequent study partners)
    }
}
