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
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.2739, longitude: -83.7485), // AAdefault
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        
        //update local ui
        self.location = location
        self.region.center = location
        
        
        // send location to db
        Task {
                await SupabaseManager.shared.updateLocation(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            }
    }
    
}
