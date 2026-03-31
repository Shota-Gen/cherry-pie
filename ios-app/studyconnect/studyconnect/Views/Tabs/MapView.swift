//
//  MapView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//
import SwiftUI
import MapKit

/// Main map tab.  Shows the user's location, study spot polygons, active user
/// pins, and an AR navigation banner.  Refreshes active users every 30 seconds
/// using structured concurrency (Task.sleep loop).
struct MapView: View {
    @State private var locManager = LocationManager()       // owns CLLocationManager; triggers permission prompt
    @State private var showARNavigationSheet = false         // fullScreenCover toggle for AR friend picker
    @State private var showARNavigationBanner = true         // AR feature banner at top of map
    @State private var studySpots: [StudySpot] = []          // study zone polygons fetched from backend API
    @State private var activeUsers: [ActiveStudyUser] = []   // friends currently checked-in at study spots
    
    private let studySpotService = StudySpotService()
    
    // .userLocation starts the camera at the user's GPS position;
    // .automatic fallback handles the case where location isn't available yet
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        // SwiftUI Map with bindings for camera position — the user can pan/zoom
        // freely because we use a @State binding, not a fixed region
        Map(position: $position) {
            // Blue dot for the user's own location
            UserAnnotation()

            // Render each study spot as a semi-transparent blue polygon overlay.
            // The spot data comes from the backend RPC; each spot has a GeoJSON
            // polygon stored in Supabase that gets decoded into [CLLocationCoordinate2D].
            ForEach(studySpots) { spot in
                let coords = spot.polygonCoordinates
                // Polygons need at least 3 vertices to be valid
                if coords.count >= 3 {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.blue.opacity(0.2))  // semi-transparent fill
                        .stroke(.blue, lineWidth: 2)          // visible border

                    // Place a book icon at the polygon centroid as a map label
                    if let center = centroid(of: coords) {
                        Annotation(spot.name, coordinate: center) {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(.white.opacity(0.85))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                }
            }

            // Green person pins for friends currently studying at campus spots.
            // Each ActiveStudyUser contains a coordinate from the backend.
            ForEach(activeUsers) { user in
                Annotation(user.displayName, coordinate: user.coordinate) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                        .padding(6)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()   // "recenter on me" button
            MapCompass()              // compass indicator in top corner
            MapPitchToggle()          // 2D ↔ 3D toggle
        }
        // AR navigation banner overlay — sits above the map content
        .overlay(alignment: .top) {
            if showARNavigationBanner {
                ARNavigationBanner {
                    showARNavigationSheet = true  // opens AR friend picker sheet
                }
                .padding(.top, 18)
                .frame(maxWidth: 260, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Full-screen cover for AR flow — presents ARNavigationSelectFriendView
        // modally so it gets its own NavigationStack
        .fullScreenCover(isPresented: $showARNavigationSheet) {
            NavigationStack {
                ARNavigationSelectFriendView()
                    .background(Color.black.edgesIgnoringSafeArea(.all))
            }
        }
        // Initial data fetch — runs once when the view appears.
        // Loads study spot polygons and active user locations in parallel.
        .task {
            studySpots = await studySpotService.getStudySpots()
            activeUsers = await studySpotService.getActiveUsers()
        }
        // Background polling loop — refreshes active users every 30 seconds.
        // Uses structured concurrency: the task is automatically cancelled
        // when the view disappears, breaking the while loop cleanly.
        .task(id: "refresh") {
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(30))
                    activeUsers = await studySpotService.getActiveUsers()
                }
            } catch is CancellationError {
                // View disappeared — exit the refresh loop cleanly
            } catch {
                print("Refresh task failed: \(error)")
            }
        }
    }

    /// Compute the centroid (average lat/lng) of a polygon for label placement.
    /// This gives an approximate visual center — good enough for small campus polygons.
    private func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coords.isEmpty else { return nil }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lng = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// Gradient pill banner displayed at the top of the map.
/// Tapping it opens the AR Navigation friend-selection sheet.
private struct ARNavigationBanner: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // ARKit icon inside a small white circle
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "arkit")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.00, green: 0.47, blue: 1.00))
                    }

                Text("AR navigation available")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                // Chevron affordance — indicates tappability
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            // Blue gradient background matching the app's accent color scheme
            .background(
                LinearGradient(
                    colors: [Color(red: 0.22, green: 0.61, blue: 0.99), Color(red: 0.44, green: 0.70, blue: 1.00)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
            .frame(maxWidth: 260)
        }
        .buttonStyle(PlainButtonStyle()) // no default button tint
    }
}

/// UIKit UIVisualEffectView wrapper for blur effects in SwiftUI.
/// Used by the AR navigation overlay for the frosted-glass look.
private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
