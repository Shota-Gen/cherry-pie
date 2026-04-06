//  FriendRequestService.swift
//  studyconnect
//
//

import Foundation

class FriendRequestService {
    /// Fetches incoming friend requests for the current user.
    func getIncomingRequests() async -> [FriendRequest] {
        // TODO: Implement backend call
        return []
    }
    /// Accepts a friend request and adds both users as friends.
    func acceptRequest(requestId: UUID) async {
        // TODO: Implement backend call
    }
    /// Rejects a friend request and removes it from both users' views.
    func rejectRequest(requestId: UUID) async {
        // TODO: Implement backend call
    }
}
