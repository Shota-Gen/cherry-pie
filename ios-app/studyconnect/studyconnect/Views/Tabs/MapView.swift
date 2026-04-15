//
//  MapView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//
import SwiftUI
import MapKit
import Auth

struct MapView: View {
    @Environment(\.supabaseManager) var supabase
    
    private var profileService = ProfileService()

    @State private var locManager = LocationManager()
    @State private var showARNavigationSheet = false
    @State private var showARNavigationBanner = false
    @State private var studySpots: [StudySpot] = []
    @State private var activeUsers: [ActiveStudyUser] = []
    
    @State private var nearbyNavigation: NearbyNavigationService? = nil
    
    private let studySpotService = StudySpotService()
    
    // This allows the map to start at the user's location and
    // stay interactive (panning/zooming won't be fought)
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            // Render each study spot as a polygon overlay
            ForEach(studySpots) { spot in
                let coords = spot.polygonCoordinates
                if coords.count >= 3 {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 2)

                    // Add a label at the centroid
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

            // Render active users inside study zones
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
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .overlay(alignment: .top) {
            if showARNavigationBanner {
                ARNavigationBanner {
                    showARNavigationSheet = true
                }
                .padding(.top, 18)
                .frame(maxWidth: 260, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showARNavigationSheet) {
            NavigationStack {
                ARNavigationSelectFriendView(nearbyNavigation: $nearbyNavigation)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
            }
        }
        .task {
            studySpots = await studySpotService.getStudySpots()
            activeUsers = await studySpotService.getActiveUsers()
            
            // retrieve the current user
            var userprofile: UserProfile? = nil
            do {
                userprofile = try await profileService.fetchMyProfile(
                    userId: supabase.session!.user.id,
                    fallbackEmail: supabase.session!.user.email
                )
            } catch {
                userprofile = UserProfile(userId: supabase.session!.user.id, displayName: "Unknown", email: "unknown", studySpot: "unknown", distanceMiles: 0.0)
            }
            nearbyNavigation = NearbyNavigationService(user: userprofile!, locationManager: locManager)
            nearbyNavigation!.broadcastUser()
            showARNavigationBanner = true
        }
        .task(id: "refresh") {
            // Refresh active users every 30 seconds
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(30))
                    activeUsers = await studySpotService.getActiveUsers()
                }
            } catch is CancellationError {
                // Task was cancelled (e.g. view disappeared), exit cleanly
            } catch {
                print("Refresh task failed: \(error)")
            }
        }
    }

    /// Compute the centroid of a polygon for label placement
    private func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coords.isEmpty else { return nil }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lng = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

private struct ARNavigationBanner: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
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
        .buttonStyle(PlainButtonStyle())
    }
}

private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
