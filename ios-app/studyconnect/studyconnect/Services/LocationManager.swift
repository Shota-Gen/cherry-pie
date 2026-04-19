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
// Heading still requires the classic CLLocationManagerDelegate pattern.
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    var location: CLLocationCoordinate2D?
    public var altitude: Double = 0
    /// Device heading in degrees clockwise from true north (0 = N, 90 = E).
    /// -1 when heading is unavailable (e.g. simulator, magnetic interference).
    public var trueHeading: CLLocationDirection = -1
    @ObservationIgnored private var updateTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestAlwaysAuthorization()
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
        manager.delegate = self

        startUpdates()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    deinit {
        updateTask?.cancel()
        manager.stopUpdatingHeading()
    }

    private func startUpdates() {
        updateTask = Task { [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard let self = self, let newLocation = update.location else { continue }

                    self.location = newLocation.coordinate
                    self.altitude = newLocation.altitude

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

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer true heading; fall back to magnetic when true is unavailable (< 0).
        if newHeading.headingAccuracy < 0 { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        trueHeading = heading
    }
}
