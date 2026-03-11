//
//  SessionService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/10/26.
//

import Foundation

class SessionService {

    // STUB: Returns all available study spots.
    func getStudySpots() -> [StudySpot] {
        return [
            StudySpot(spotId: UUID(), name: "UGLI"),
            StudySpot(spotId: UUID(), name: "Law Library"),
            StudySpot(spotId: UUID(), name: "Ross Building"),
            StudySpot(spotId: UUID(), name: "Duderstadt"),
            StudySpot(spotId: UUID(), name: "Hatcher")
        ]
        // TODO: SELECT spot_id, name, is_active, created_at FROM public.study_spots WHERE is_active = TRUE
    }

    // STUB: Returns suggested study session slots.
    // - config: session parameters (date range, duration, time window, friends)
    // Generates 1–3 slots per day with 30-min granularity within the time window.
    // Never returns a slot where all friends are busy; may return slots with 1–2 busy.
    // TODO: Replace with Google Calendar API + LLM availability prediction.
    func getSuggestedSlots(config: SessionConfig) -> [TimeSlot] {
        let cal = Calendar.current
        var slots: [TimeSlot] = []
        let startDay = cal.startOfDay(for: config.startDate)
        let endDay   = cal.startOfDay(for: config.endDate)
        var currentDay = startDay

        while currentDay <= endDay {
            let windowStart = timeOnDay(config.earliestStart, day: currentDay, cal: cal)
            let windowEnd   = timeOnDay(config.latestEnd,     day: currentDay, cal: cal)
            let durationSec = TimeInterval(config.duration * 3600)

            var candidates: [Date] = []
            var t = windowStart
            while t.addingTimeInterval(durationSec) <= windowEnd {
                candidates.append(t)
                t = t.addingTimeInterval(1800) // 30-min steps
            }

            if !candidates.isEmpty {
                let count = Int.random(in: 1...min(3, candidates.count))
                let chosen = candidates.shuffled().prefix(count).sorted()
                for start in chosen {
                    let busy = randomBusy(from: config.selectedFriends)
                    let busyIds = Set(busy.map(\.userId))
                    let available = config.selectedFriends.filter { !busyIds.contains($0.userId) }
                    slots.append(TimeSlot(id: UUID(), start: start,
                                         end: start.addingTimeInterval(durationSec),
                                         availableFriends: available, busyFriends: busy))
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = next
        }
        return slots
    }

    private func timeOnDay(_ ref: Date, day: Date, cal: Calendar) -> Date {
        let h = cal.component(.hour,   from: ref)
        let m = cal.component(.minute, from: ref)
        return cal.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
    }

    // Returns 0–2 random busy friends, always leaving ≥1 available.
    private func randomBusy(from friends: [UserProfile]) -> [UserProfile] {
        guard friends.count > 1, Bool.random() else { return [] }
        let numBusy = Int.random(in: 1...min(2, friends.count - 1))
        return Array(friends.shuffled().prefix(numBusy))
    }

    // STUB: Create a study session and send invites.
    // - createdBy:     UUID of the signed-in user
    // - spotId:        optional UUID of a study spot
    // - starts:        session start time
    // - ends:          session end time
    // - invitedUsers:  UUIDs of all invited friends (owner is auto-added as accepted)
    func createSession(createdBy: UUID, spotId: UUID?, starts: Date, ends: Date, invitedUsers: [UUID]) {
        print("Creating session from \(starts) to \(ends) for \(invitedUsers.count) invitees.")
        // TODO: Insert into public.sessions, then insert rows into public.session_members:
        //   - owner row: status = 'accepted'
        //   - invitee rows: status = 'pending'
    }
}
