//
//  MapView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//
import SwiftUI
import MapKit

struct MapView: View {
    @State private var locManager = LocationManager()
    @State private var showARNavigationSheet = false
    @State private var showARNavigationBanner = true
    
    // This allows the map to start at the user's location and
    // stay interactive (panning/zooming won't be fought)
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        ZStack(alignment: .top) {
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
                ARNavigationSelectFriendView()
                    .background(Color.black.edgesIgnoringSafeArea(.all))
            }
        }
    }
}

private struct ARNavigationBanner: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 30, height: 30)

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
