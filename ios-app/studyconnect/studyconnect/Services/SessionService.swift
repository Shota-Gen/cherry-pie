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

    // STUB: Create a study session and send invites.
    // - createdBy:     UUID of the signed-in user
    // - spotId:        UUID of the selected study spot
    // - starts:        session start time
    // - ends:          session end time
    // - invitedUsers:  UUIDs of all invited friends (owner is auto-added as accepted)
    func createSession(createdBy: UUID, spotId: UUID, starts: Date, ends: Date, invitedUsers: [UUID]) {
        print("Creating session at \(spotId) from \(starts) to \(ends) for \(invitedUsers.count) invitees.")
        // TODO: Insert into public.sessions, then insert rows into public.session_members:
        //   - owner row: status = 'accepted'
        //   - invitee rows: status = 'pending'
    }
}
