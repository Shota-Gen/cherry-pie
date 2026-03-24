//
//  StudySpot.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/10/26.
//

import Foundation
import CoreLocation

struct StudySpot: Identifiable, Codable {
    // Mirrors public.study_spots in Supabase.
    var spotId: UUID
    var name: String
    var isActive: Bool = true
    /// Polygon vertices as [[lng, lat], [lng, lat], ...]
    var coordinates: [[Double]] = []
    var id: UUID { spotId }

    /// Convert the raw coordinate pairs into CLLocationCoordinate2D for MapKit
    var polygonCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count == 2 else { return nil }
            // pair[0] = longitude, pair[1] = latitude (GeoJSON convention)
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}
