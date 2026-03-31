//
//  TimeSlot.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import Foundation

struct TimeSlot: Identifiable, Hashable {
    let id: UUID
    let start: Date
    let end: Date
    let availableFriends: [UserProfile]
    let busyFriends: [UserProfile]

    var isEveryoneFree: Bool { busyFriends.isEmpty }
}
