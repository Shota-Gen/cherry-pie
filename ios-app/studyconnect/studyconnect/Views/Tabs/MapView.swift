//
//  MapView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//
import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var locManager = LocationManager()
    
    // This allows the map to start at the user's location and
    // stay interactive (panning/zooming won't be fought)
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            
            Annotation("UGLI", coordinate: CLLocationCoordinate2D(latitude: 42.2743, longitude: -83.7397)) {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass() // Shows the compass when rotating
            MapPitchToggle() 
        }
    }
}
