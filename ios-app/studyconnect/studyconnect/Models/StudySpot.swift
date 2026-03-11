//
//  StudySpot.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/10/26.
//

import Foundation

struct StudySpot: Identifiable, Codable {
    // Mirrors public.study_spots in Supabase.
    // Note: geofence (PostGIS geography) is server-side only and excluded.
    var spotId: UUID
    var name: String
    var isActive: Bool = true
    var createdAt: Date? = nil
    var id: UUID { spotId }
}
