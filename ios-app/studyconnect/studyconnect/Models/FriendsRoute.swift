//
//  FriendsRoute.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

/// Typed navigation enum for the Friends tab’s NavigationStack.
/// Each case maps to a destination view in the session-scheduling flow.
/// Using an enum allows `path = NavigationPath()` to pop to root.
enum FriendsRoute: Hashable {
    case selectFriends                          // → SelectFriendsView
    case sessionDetails([UserProfile])          // → SessionDetailsView
    case findAvailability(SessionConfig)         // → FindAvailabilityView
}
