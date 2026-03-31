//
//  SessionConfig.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

/// Bundles all session scheduling parameters chosen in SessionDetailsView
/// so they can be passed as a single Hashable value through FriendsRoute
/// to FindAvailabilityView.
struct SessionConfig: Hashable {
    var selectedFriends: [UserProfile]  // friends the user wants to invite
    var startDate: Date                 // first day of the search window
    var endDate: Date                   // last day of the search window
    var duration: Int                   // session length in hours (1–8)
    var earliestStart: Date             // earliest time-of-day (only h/m used)
    var latestEnd: Date                 // latest time-of-day (only h/m used)
}
