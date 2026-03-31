//
//  FriendsRoute.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

// Drives all navigation within FriendsView's NavigationStack so the path can be
// reset programmatically (e.g., "Back to Home" from FindAvailabilityView).
enum FriendsRoute: Hashable {
    case selectFriends
    case sessionDetails([UserProfile])
    case findAvailability(SessionConfig)
}
