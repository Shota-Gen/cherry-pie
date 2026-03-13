//
//  SessionInviteService.swift
//  studyconnect
//
//

import Foundation

private var stubInvites: [SessionInvite] = [
    SessionInvite(
        id: UUID(),
        fromUser: UserProfile(userId: UUID(), displayName: "Leo Messi", email: "leo@umich.edu", studySpot: "Michigan Union", distanceMiles: 0.3),
        startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
        endTime: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date(),
        createdAt: Date(timeIntervalSinceNow: -120) // 2 minutes ago
    )
]

class SessionInviteService {
    
    // STUB: Fetch pending session invites
    func getPendingInvites() -> [SessionInvite] {
        return stubInvites
        // TODO: Implement actual API call to fetch pending invites
    }
    
    // STUB: Accept a session invite
    func acceptInvite(inviteId: UUID) {
        print("Accepting invite with ID: \(inviteId)")
        stubInvites.removeAll { $0.id == inviteId }
        // TODO: Implement actual API call to accept invite
    }
    
    // STUB: Decline a session invite
    func declineInvite(inviteId: UUID) {
        print("Declining invite with ID: \(inviteId)")
        stubInvites.removeAll { $0.id == inviteId }
        // TODO: Implement actual API call to decline invite
    }
}
