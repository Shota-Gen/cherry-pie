//
//  LocationManager.swift
//  studyconnect
//
//  Created by Ayah Chahine using Gemini on 3/9/26.
//
import Foundation
import CoreLocation
import MapKit
import Combine

// Uses CLLocationManagerDelegate pattern as it's the standard CoreLocation API for efficient location tracking.
// This is the recommended approach by Apple for iOS location updates and is more efficient than
// AsyncStream wrappers for continuous location monitoring.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        
        // Update the coordinate for Supabase
        self.location = location
        
        // Send location to db
        Task {
            await SupabaseManager.shared.updateLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
        }
    }
}
