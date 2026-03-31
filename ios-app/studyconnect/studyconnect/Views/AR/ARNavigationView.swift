import SwiftUI
import RealityKit
import ARKit
import UIKit

/// Full-screen AR navigation experience.  Uses RealityKit + ARKit to
/// display the camera feed with overlaid compass arrow, distance indicator,
/// and target friend card.  The Coordinator runs a 30fps Timer to compute
/// distance/bearing/heading from the AR camera transform.
struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile                            // which friend we're navigating to
    @State private var distanceToTarget: Float = 5.0   // live distance in meters (updated 30fps by Coordinator)
    @State private var bearingToTarget: Float = 0      // angle from camera forward to target, in degrees
    @State private var deviceHeading: Float = 0        // compass heading derived from AR camera transform
    @State private var isHeadingAvailable = false       // becomes true once the first AR frame is processed

    var body: some View {
        // ZStack justified: layering AR camera feed (bottom) with compass arrow,
        // navigation bar, and target card overlays on top.
        ZStack {
            // Black background visible if AR feed hasn't started yet
            Color.black
                .ignoresSafeArea(edges: .all)

            // RealityKit AR camera feed — UIViewRepresentable wrapping an ARView.
            // The Coordinator inside runs a 30fps Timer that reads the AR camera
            // transform and updates distance/bearing/heading bindings.
            ARViewContainer(friend: friend, distanceToTarget: $distanceToTarget, bearingToTarget: $bearingToTarget, deviceHeading: $deviceHeading, isHeadingAvailable: $isHeadingAvailable)
                .ignoresSafeArea(edges: .all)

            // Floating compass arrow that rotates to point toward the target
            compassArrow(bearing: bearingToTarget, heading: deviceHeading)

            // Top navigation bar + bottom target card, vertically spaced
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)

                Spacer()

                targetCard
                    .padding(.bottom, 60)
            }
        }
    }

    /// Floating directional arrow icon that rotates based on the relative angle
    /// between the camera's forward direction and the target's position.
    private func compassArrow(bearing: Float, heading: Float) -> some View {
        // relativeAngle determines rotation: 0° = straight ahead, positive = right
        let relativeAngle = bearing - heading
        
        return VStack {
            Image(systemName: "location.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color(red: 0.22, green: 0.61, blue: 0.99))
                .rotationEffect(.degrees(Double(relativeAngle)))
                .padding(16)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 120)
    }

    /// Top bar pill: compass icon, "NAVIGATING TO [name]", live distance badge, close button.
    /// Styled as a floating dark capsule with a subtle border and shadow.
    private var topBar: some View {
        HStack(spacing: 12) {
            // Compass icon
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

            // Live distance badge (e.g. "5m")
            Text("\(Int(distanceToTarget))m")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.22, green: 0.61, blue: 0.99))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(18)

            // Close button — dismisses the full-screen AR experience
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

    /// Bottom card showing the target friend's avatar, name, and status.
    /// Uses a frosted-glass (BlurView) background for the translucent AR look.
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

/// UIViewRepresentable that creates and manages the RealityKit ARView.
/// The Coordinator runs a 30fps Timer (justified: continuous real-time tracking
/// needs frame-rate updates) to extract distance, bearing, and heading from
/// the AR camera's world transform matrix.
private struct ARViewContainer: UIViewRepresentable {
    let friend: UserProfile
    @Binding var distanceToTarget: Float
    @Binding var bearingToTarget: Float
    @Binding var deviceHeading: Float
    @Binding var isHeadingAvailable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR world tracking with compass-aligned heading
        // so the AR coordinate system's -Z axis points north.
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config)
        
        // Start the 30fps tracking loop in the Coordinator
        let coordinator = context.coordinator
        coordinator.trackingUpdates(arView: arView, distanceBinding: $distanceToTarget, bearingBinding: $bearingToTarget, headingBinding: $deviceHeading, isHeadingAvailableBinding: $isHeadingAvailable)
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    /// Coordinator runs a repeating Timer at ~30fps to compute spatial
    /// relationships between the AR camera and a fixed target position.
    class Coordinator {
        private var timer: Timer?
        
        func trackingUpdates(arView: ARView, distanceBinding: Binding<Float>, bearingBinding: Binding<Float>, headingBinding: Binding<Float>, isHeadingAvailableBinding: Binding<Bool>) {
            // Hardcoded target position in AR world space (will be replaced
            // with real friend coordinates from the backend)
            let targetWorldPosition = SIMD3<Float>(2.0, 0.0, -4.5)
            
            // Timer fires every 33ms (~30fps) — justified per RULES.md:
            // continuous frame processing for real-time AR navigation.
            timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
                guard let frame = arView.session.currentFrame else { return }
                
                // Extract camera position from the 4x4 transform matrix (column 3 = translation)
                let cameraTransform = frame.camera.transform
                let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
                
                // Distance = Euclidean length of vector from camera to target
                let deltaVector = targetWorldPosition - cameraPosition
                let distance = simd_length(deltaVector)
                
                // Bearing = angle between camera's forward vector and the direction to target.
                // Uses dot products with forward and right camera axes, then atan2.
                let forward = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
                let right = SIMD3<Float>(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)
                let forwardDist = simd_dot(deltaVector, forward)
                let rightDist = simd_dot(deltaVector, right)
                let angleRadians = atan2(rightDist, forwardDist)
                let bearing = angleRadians * 180 / .pi
                
                // Heading = compass direction the camera is facing (for UI display)
                let heading = atan2(forward.x, -forward.z) * 180 / .pi
                
                // @MainActor dispatch: Timer fires on RunLoop, but SwiftUI
                // bindings must be updated on the main actor.
                Task { @MainActor in
                    distanceBinding.wrappedValue = distance
                    bearingBinding.wrappedValue = bearing
                    headingBinding.wrappedValue = heading
                    isHeadingAvailableBinding.wrappedValue = true
                }
            }
        }
        
        deinit {
            timer?.invalidate()  // clean up Timer to prevent retain cycles
        }
    }
}


// MARK: - Helper Views
/// UIKit UIVisualEffectView wrapper for the frosted-glass material behind AR overlay cards.
private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
