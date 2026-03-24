//
//  ActiveStudyUser.swift
//  studyconnect
//

import Foundation
import CoreLocation

/// A user currently located inside a study zone polygon.
struct ActiveStudyUser: Identifiable, Codable {
    var userId: UUID
    var displayName: String
    var lastKnownLat: Double
    var lastKnownLng: Double
    var spotName: String

    var id: UUID { userId }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lastKnownLat, longitude: lastKnownLng)
    }
}
