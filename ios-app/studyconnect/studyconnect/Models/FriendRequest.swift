//  FriendRequest.swift
//  studyconnect
//
//

import Foundation

/// Represents a friend request / friendship row from the `friends` table.
/// A single row has `user_id` (sender) and `friend_id` (receiver).
/// `user_status` is auto-set to "accepted" for the sender.
/// `friend_status` starts as "pending" for the receiver.
struct FriendRequest: Identifiable, Codable, Hashable {
    enum Status: String, Codable, Hashable {
        case pending, accepted
    }

    let userId: UUID
    let friendId: UUID
    let userStatus: Status
    let friendStatus: Status
    let createdAt: Date

    // The row is identified by the composite key; use a combined id for SwiftUI.
    var id: String { "\(userId)-\(friendId)" }

    /// The profile of the user who sent the request (populated after join).
    var fromUser: UserProfile?

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
