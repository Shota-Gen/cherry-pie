//  FriendRequest.swift
//  studyconnect
//
//

import Foundation

/// Represents a pending friend request between two users.
struct FriendRequest: Identifiable, Codable, Hashable {
    enum Status: String, Codable, Hashable {
        case pending, accepted, declined
    }

    let id: UUID           // Unique request ID
    let fromUser: UserProfile // Who sent the request
    let toUser: UserProfile   // Who received the request
    let createdAt: Date
    let status: Status

    // Relative time (e.g. "2m ago")
    var createdTimeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "Just now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(interval / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}
