//
//  SessionConfig.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

/// Bundles all parameters chosen in SessionDetailsView so they can be
/// passed as a single Hashable value through FriendsRoute.
struct SessionConfig: Hashable {
    var selectedFriends: [UserProfile]
    var startDate: Date
    var endDate: Date
    var duration: Int        // hours, 1–8
    var earliestStart: Date  // time-of-day reference (only h/m used)
    var latestEnd: Date      // time-of-day reference (only h/m used)

    // Session metadata entered by the user
    var title: String
    var locationName: String
    var description: String
    var addGoogleMeet: Bool
}
