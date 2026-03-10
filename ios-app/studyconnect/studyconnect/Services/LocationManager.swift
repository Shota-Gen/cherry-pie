//
//  LocationManager.swift
//  studyconnect
//
//  Created by Ayah Chahine on 3/9/26.
//
import Foundation
import CoreLocation
import MapKit
import Combine

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
