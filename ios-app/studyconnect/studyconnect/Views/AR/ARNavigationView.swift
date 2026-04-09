import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile
    @Binding var nearbyNavigation: NearbyNavigationService!
    @State private var distanceToTarget: Float = 5.0
    /// Signed angle (degrees) in the camera’s horizontal plane from look direction toward the target — use alone for overlay rotation (do not mix with world heading).
    @State private var bearingToTarget: Float = 0
    /// Mirrored from `nearbyNavigation` on each AR frame so SwiftUI reliably redraws (service updates alone do not always refresh through `@Binding`).
    @State private var navigationSourceDebug: String = NavigationSourceMode.unavailable.debugLabel

    var body: some View {
        // ZStack required for layering AR content with overlaid UI elements (compass arrow, top bar, target card)
        ZStack {
            Color.black
                .ignoresSafeArea(edges: .all)

            ARViewContainer(
                friend: friend,
                distanceToTarget: $distanceToTarget,
                bearingToTarget: $bearingToTarget,
                navigationSourceDebug: $navigationSourceDebug,
                nearbyNavigation: $nearbyNavigation
            )
                .ignoresSafeArea(edges: .all)

            // Direction arrow — rotation is camera-relative azimuth only (matches the live camera feed).
            compassArrow(cameraRelativeAzimuthDegrees: bearingToTarget)

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)

                Spacer()

                targetCard
                    .padding(.bottom, 60)
            }

            // Debug on top so the target card / chrome never occludes it; value driven by @State from the AR timer.
            VStack {
                Spacer()
                Text("Source: \(navigationSourceDebug)")
                    .font(.caption.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
        .onAppear() {
            // TODO: beginSearch
            nearbyNavigation.searchUsers()
        }
        .onDisappear() {
            // TODO: beginBroadcast
            nearbyNavigation.broadcastUser()
        }
    }

    private func compassArrow(cameraRelativeAzimuthDegrees: Float) -> some View {
        // `cameraRelativeAzimuthDegrees` is atan2(right, forward) in the plane perpendicular to camera up — already accounts for device rotation via the AR camera pose. Do not subtract a separate world heading.
        VStack {
            Image(systemName: "location.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color(red: 0.22, green: 0.61, blue: 0.99))
                .rotationEffect(.degrees(Double(cameraRelativeAzimuthDegrees)))
                .padding(16)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 120)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("NAVIGATING TO")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)

                Text(friend.displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Spacer()

            Text("\(String(format: "%.2f", distanceToTarget))m")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.22, green: 0.61, blue: 0.99))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(18)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.black.opacity(0.78)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private var targetCard: some View {
        VStack(spacing: 10) {
            Text("TARGET")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(12)

            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage, size: 72)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 90, height: 90)
                )

            Text(friend.displayTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Here now")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35))
            .cornerRadius(20)
        }
        .padding(22)
        .background(
            BlurView(style: .systemThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 12)
        .padding(.horizontal, 26)
    }
}

private struct ARViewContainer: UIViewRepresentable {
    let friend: UserProfile
    @Binding var distanceToTarget: Float
    @Binding var bearingToTarget: Float
    @Binding var navigationSourceDebug: String
    @Binding var nearbyNavigation: NearbyNavigationService!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        
////         Configure R with heading alignment
//        let config = ARWorldTrackingConfiguration()
//        config.worldAlignment = .gravityAndHeading
//        arView.session.run(config)
        
//         Set up location tracking through periodic updates
        let coordinator = context.coordinator
        coordinator.trackingUpdates(
            nearbyNavigation: nearbyNavigation,
            view: nearbyNavigation.arview,
            distanceBinding: $distanceToTarget,
            bearingBinding: $bearingToTarget,
            navigationSourceDebugBinding: $navigationSourceDebug
        )
        
        return nearbyNavigation.arview
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    class Coordinator {
        private var timer: Timer?
        
        func trackingUpdates(
            nearbyNavigation: NearbyNavigationService,
            view: ARView,
            distanceBinding: Binding<Float>,
            bearingBinding: Binding<Float>,
            navigationSourceDebugBinding: Binding<String>
        ) {
            // Target position in world space
//            let targetWorldPosition: SIMD3<Float> = nearbyNavigation.target
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
                // print("======")
                // print("User GPS: \(String(describing: nearbyNavigation.gps))")
                // print("User Altitude: \(nearbyNavigation.altitude)")
                // print("Target GPS: lat=\(String(describing: nearbyNavigation.targetUser?.lastKnownLat)), lng=\(String(describing: nearbyNavigation.targetUser?.lastKnownLng))")
                // print("Target Altitude: \(nearbyNavigation.targetUser?.altitude ?? 0)")
                guard let frame = view.session.currentFrame else { return }
                nearbyNavigation.updateBestTargetEstimate(cameraTransform: frame.camera.transform)
                let targetWorldPosition = nearbyNavigation.target
                
                let cameraTransform = frame.camera.transform
                let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
                
                // Calculate distance
                let deltaVector = targetWorldPosition - cameraPosition
                let distance = simd_length(deltaVector)
                
                // Camera-relative azimuth: angle in the horizontal plane (perpendicular to camera up) from look direction toward the target.
                let forward = simd_normalize(SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z))
                let right = simd_normalize(SIMD3<Float>(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z))
                let up = simd_normalize(SIMD3<Float>(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z))
                let deltaHorizontal = deltaVector - up * simd_dot(deltaVector, up)
                let forwardDist = simd_dot(deltaHorizontal, forward)
                let rightDist = simd_dot(deltaHorizontal, right)
                let bearing: Float
                if simd_length_squared(deltaHorizontal) < 1e-8 {
                    bearing = 0
                } else {
                    bearing = atan2(rightDist, forwardDist) * 180 / .pi
                }
                
                // Use MainActor to update bindings from AR calculation loop
                Task { @MainActor in
                    // `targetDistance` is updated with `target` via `updateBestTargetEstimate`.
                    distanceBinding.wrappedValue = nearbyNavigation.targetDistance > 0 ? nearbyNavigation.targetDistance : distance
                    bearingBinding.wrappedValue = bearing
                    navigationSourceDebugBinding.wrappedValue = nearbyNavigation.navigationSourceMode.debugLabel
                }
            }
        }
        
        deinit {
            timer?.invalidate()
        }
    }
}


// MARK: - Helper Views
private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
