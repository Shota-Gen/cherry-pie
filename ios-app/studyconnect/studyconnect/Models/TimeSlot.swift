//
//  TimeSlot.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

/// A suggested study time slot returned by SessionService.
/// Contains the friends who are available vs busy during this window.
struct TimeSlot: Identifiable, Hashable {
    let id: UUID
    let start: Date                           // slot start time
    let end: Date                             // slot end time
    let availableFriends: [UserProfile]       // friends free during this slot
    let busyFriends: [UserProfile]            // friends with conflicts

    /// True when every invited friend is available.
    var isEveryoneFree: Bool { busyFriends.isEmpty }
}
