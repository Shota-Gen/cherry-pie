//
//  FriendsService.swift
//  studyconnect
//
//  Created by Copilot on 3/6/26.
//

import Foundation

class FriendsService {
    
    // STUB: Fetch friends list
    func getFriendsList() -> [Friend] {
        return [
            Friend(icon: "person.circle.fill", name: "Alice Johnson", location: "Engineering Building", distance: 0.2),
            Friend(icon: "person.circle.fill", name: "Bob Smith", location: "Library", distance: 0.5),
            Friend(icon: "person.circle.fill", name: "Carol Davis", location: "Student Center", distance: 1.2),
            Friend(icon: "person.circle.fill", name: "David Wilson", location: "Dining Hall", distance: 1.8),
            Friend(icon: "person.circle.fill", name: "Emma Brown", location: "Gym", distance: 0.3),
        ]
    }
    
    // STUB: Add a friend
    func addFriend(name: String, email: String) {
        print("Adding friend: \(name) (\(email))")
        // TODO: Implement actual API call
    }
    
    // STUB: Delete a friend
    func deleteFriend(id: UUID) {
        print("Deleting friend with ID: \(id)")
        // TODO: Implement actual API call
    }
}
