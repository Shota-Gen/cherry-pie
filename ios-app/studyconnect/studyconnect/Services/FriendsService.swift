//
//  FriendsService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import Foundation

class FriendsService {

    // STUB: Fetch friends list
    func getFriendsList() -> [UserProfile] {
        return [
            UserProfile(userId: UUID(), displayName: "Alice Johnson",  email: "alice@umich.edu", studySpot: "Engineering Building", distanceMiles: 0.2),
            UserProfile(userId: UUID(), displayName: "Bob Smith",      email: "bob@umich.edu",   studySpot: "Library",             distanceMiles: 0.5),
            UserProfile(userId: UUID(), displayName: "Carol Davis",    email: "carol@umich.edu", studySpot: "Student Center",      distanceMiles: 1.2),
            UserProfile(userId: UUID(), displayName: "David Wilson",   email: "david@umich.edu", studySpot: "Dining Hall",         distanceMiles: 1.8),
            UserProfile(userId: UUID(), displayName: "Emma Brown",     email: "emma@umich.edu",  studySpot: "Gym",                 distanceMiles: 0.3)
        ]
        // TODO: Implement actual API call to fetch friends list
    }

    // STUB: Add a friend by email
    func addFriend(email: String) {
        print("Adding friend by email: \(email)")
        // TODO: Implement actual API call
    }

    // STUB: Delete a friend
    func deleteFriend(id: UUID) {
        print("Deleting friend with ID: \(id)")
        // TODO: Implement actual API call
    }
}
