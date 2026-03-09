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
    var body: some View {
        Map(position: .constant(.region(locManager.region))) {
            UserAnnotation() // show user
            
            //add study zones
            Annotation("UGLI", coordinate: CLLocationCoordinate2D(latitude: 42.2743, longitude: -83.7397)) {
                Image(systemName: "book.fill").foregroundColor(.blue)
            }
        }
        .onAppear {
            // register zones/fetch data
        }
    }
}
