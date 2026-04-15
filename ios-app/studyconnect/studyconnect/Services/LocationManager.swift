//
//  LocationManager.swift
//  studyconnect
//
//  Created by Ayah Chahine using Gemini on 3/9/26.
//
import Foundation
import CoreLocation
import MapKit
import Observation

// Uses modern CLLocationUpdate.liveUpdates() approach to fetch location.
// This is the recommended approach for iOS 17+ location updates.
@Observable
class LocationManager {
    private let manager = CLLocationManager()
    var location: CLLocationCoordinate2D?
    public var altitude: Double = 0
    private var updateTask: Task<Void, Never>?
    
    init() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestAlwaysAuthorization()
        
        startUpdates()
    }
    
    deinit {
        updateTask?.cancel()
    }

    private func startUpdates() {
        updateTask = Task { [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard let self = self, let newLocation = update.location else { continue }
                    
                    // Update the coordinate for Supabase
                    self.location = newLocation.coordinate
                    self.altitude = newLocation.altitude
                    
                    // Send location to db
                    Task {
                        await SupabaseManager.shared.updateLocation(
                            latitude: newLocation.coordinate.latitude,
                            longitude: newLocation.coordinate.longitude,
                            altitude: self.altitude
                        )
                    }
                }
            } catch {
                print("Failed to observe location updates: \(error)")
            }
        }
    }
}
