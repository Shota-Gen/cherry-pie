import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile
    @Binding var nearbyNavigation: NearbyNavigationService!
    @State private var distanceToTarget: Float = 0
    @State private var isTargetOnScreen = true
    /// Signed angle (degrees) in the camera’s horizontal plane from look direction toward the target — use alone for overlay rotation (do not mix with world heading).
    @State private var bearingToTarget: Float = 0
    /// Mirrored from `nearbyNavigation` on each AR frame so SwiftUI reliably redraws (service updates alone do not always refresh through `@Binding`).
    @State private var navigationSourceDebug: String = NavigationSourceMode.unavailable.debugLabel

    var body: some View {
        // ZStack required: layering AR camera feed with minimal HUD overlay
        ZStack {
            Color.black
                .ignoresSafeArea(edges: .all)

            ARBeaconViewContainer(
                friend: friend,
                nearbyNavigation: $nearbyNavigation,
                distanceToTarget: $distanceToTarget,
                isTargetOnScreen: $isTargetOnScreen,
                bearingToTarget: $bearingToTarget,
                navigationSourceDebug: $navigationSourceDebug
            )
            .ignoresSafeArea(edges: .all)

            // Direction arrow — rotation is camera-relative azimuth only (matches the live camera feed).
            compassArrow(cameraRelativeAzimuthDegrees: bearingToTarget)

            VStack {
                topBar
                    .padding(.top, 6)
                    .padding(.horizontal, 12)

                Spacer()

                if !isTargetOnScreen {
                    offScreenIndicator
                        .padding(.bottom, 40)
                }

                bottomDistancePill
                    .padding(.bottom, 30)
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
        .onAppear {
            nearbyNavigation.searchUsers()
            nearbyNavigation.runARSessionForNavigationUI()
        }
        .onDisappear {
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
        HStack(spacing: 10) {
            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Navigating to")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(friend.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.black.opacity(0.6)
                .clipShape(Capsule())
        )
    }

    // MARK: - Off-screen arrow indicator

    private var offScreenIndicator: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(0)) // TODO: rotate toward target bearing
            Text("Look around to find \(friend.displayTitle)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5).clipShape(Capsule()))
    }

    // MARK: - Bottom distance pill

    private var bottomDistancePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(proximityColor)
                .frame(width: 8, height: 8)

            Text(formattedDistance)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6).clipShape(Capsule()))
    }

    private var formattedDistance: String {
        if distanceToTarget < 1 {
            return String(format: "%.0f cm away", distanceToTarget * 100)
        }
        return String(format: "%.1f m away", distanceToTarget)
    }

    private var proximityColor: Color {
        if distanceToTarget < 2 { return .green }
        if distanceToTarget < 7 { return .yellow }
        return .orange
    }
}

// MARK: - AR View Container (RealityKit + beacon entity)

private struct ARBeaconViewContainer: UIViewRepresentable {
    let friend: UserProfile
    @Binding var nearbyNavigation: NearbyNavigationService!
    @Binding var distanceToTarget: Float
    @Binding var isTargetOnScreen: Bool
    @Binding var bearingToTarget: Float
    @Binding var navigationSourceDebug: String

    func makeCoordinator() -> Coordinator {
        Coordinator(friendName: friend.displayTitle, profileImage: friend.profileImage)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = nearbyNavigation.arview
        let coordinator = context.coordinator
        coordinator.setupBeacon(in: arView)
        coordinator.startTracking(
            arView: arView,
            nearbyNavigation: nearbyNavigation,
            distanceBinding: $distanceToTarget,
            isOnScreenBinding: $isTargetOnScreen,
            bearingBinding: $bearingToTarget,
            navigationSourceDebugBinding: $navigationSourceDebug
        )
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator {
        private let friendName: String
        private let profileImage: String
        private var beaconAnchor: AnchorEntity?
        private var beaconEntity: ModelEntity?
        private var ringEntity: ModelEntity?
        private var timer: Timer?
        private var pulsePhase: Float = 0

        init(friendName: String, profileImage: String) {
            self.friendName = friendName
            self.profileImage = profileImage
        }

        func setupBeacon(in arView: ARView) {
            let anchor = AnchorEntity(world: .zero)

            // Main beacon sphere — rendered as "purgatory" object
            // Uses UnlitMaterial so it glows and is always visible
            let beaconMesh = MeshResource.generateSphere(radius: 0.12)
            var beaconMaterial = UnlitMaterial()
            beaconMaterial.color = .init(tint: beaconColor.withAlphaComponent(0.9))
            let beacon = ModelEntity(mesh: beaconMesh, materials: [beaconMaterial])

            // Outer pulsing ring
            let ringMesh = MeshResource.generateSphere(radius: 0.18)
            var ringMaterial = UnlitMaterial()
            ringMaterial.color = .init(tint: beaconColor.withAlphaComponent(0.25))
            let ring = ModelEntity(mesh: ringMesh, materials: [ringMaterial])

            anchor.addChild(beacon)
            anchor.addChild(ring)
            arView.scene.addAnchor(anchor)

            self.beaconAnchor = anchor
            self.beaconEntity = beacon
            self.ringEntity = ring
        }

        func startTracking(
            arView: ARView,
            nearbyNavigation: NearbyNavigationService,
            distanceBinding: Binding<Float>,
            isOnScreenBinding: Binding<Bool>,
            bearingBinding: Binding<Float>,
            navigationSourceDebugBinding: Binding<String>
        ) {
            // ~30 fps update loop
            timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
                guard let self else { return }
                guard let frame = arView.session.currentFrame else { return }
                nearbyNavigation.updateBestTargetEstimate(cameraTransform: frame.camera.transform)
                let targetWorldPos = nearbyNavigation.target

                // Update beacon position with smoothing
                if let anchor = self.beaconAnchor {
                    let currentPos = anchor.position
                    let smoothed = currentPos + (targetWorldPos - currentPos) * 0.15
                    anchor.position = smoothed
                }

                // Compute distance from camera to target
                let camTransform = frame.camera.transform
                let camPos = SIMD3<Float>(
                    camTransform.columns.3.x,
                    camTransform.columns.3.y,
                    camTransform.columns.3.z
                )
                let distance = simd_length(targetWorldPos - camPos)

                // Scale beacon: larger when far, smaller when close (min 0.5, max 2.0)
                let scaleFactor = max(0.5, min(2.0, distance / 5.0))

                // Pulse effect — frequency increases as user gets closer
                let pulseSpeed: Float = max(1.0, 6.0 - distance)
                self.pulsePhase += 0.033 * pulseSpeed
                let pulseSin = (sin(self.pulsePhase) + 1.0) / 2.0 // 0..1
                let ringScale = scaleFactor * (1.0 + pulseSin * 0.5)

                self.beaconEntity?.scale = SIMD3<Float>(repeating: scaleFactor)
                self.ringEntity?.scale = SIMD3<Float>(repeating: ringScale)

                // Update ring opacity via material
                let ringAlpha = 0.1 + pulseSin * 0.25
                var ringMat = UnlitMaterial()
                ringMat.color = .init(tint: self.beaconColor.withAlphaComponent(CGFloat(ringAlpha)))
                self.ringEntity?.model?.materials = [ringMat]

                // Beacon color intensifies when closer
                let beaconAlpha: CGFloat = distance < 3.0 ? 1.0 : 0.8
                var beaconMat = UnlitMaterial()
                beaconMat.color = .init(tint: self.beaconColor.withAlphaComponent(beaconAlpha))
                self.beaconEntity?.model?.materials = [beaconMat]

                // Check if target is on screen
                let projected = frame.camera.projectPoint(
                    targetWorldPos,
                    orientation: .portrait,
                    viewportSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                )
                let screenBounds = UIScreen.main.bounds
                let onScreen = screenBounds.contains(CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)))

                // Camera-relative azimuth: angle in the horizontal plane (perpendicular to camera up) from look direction toward the target.
                let deltaVector = targetWorldPos - camPos
                let forward = simd_normalize(SIMD3<Float>(-camTransform.columns.2.x, -camTransform.columns.2.y, -camTransform.columns.2.z))
                let right = simd_normalize(SIMD3<Float>(camTransform.columns.0.x, camTransform.columns.0.y, camTransform.columns.0.z))
                let up = simd_normalize(SIMD3<Float>(camTransform.columns.1.x, camTransform.columns.1.y, camTransform.columns.1.z))
                let deltaHorizontal = deltaVector - up * simd_dot(deltaVector, up)
                let forwardDist = simd_dot(deltaHorizontal, forward)
                let rightDist = simd_dot(deltaHorizontal, right)
                let bearingDegrees: Float
                if simd_length_squared(deltaHorizontal) < 1e-8 {
                    bearingDegrees = 0
                } else {
                    bearingDegrees = atan2(rightDist, forwardDist) * 180 / .pi
                }
                
                // Timer runs on the main thread’s RunLoop — avoid piling up `Task { @MainActor }` work, which can stall the UI when NI is busy.
                let mode = nearbyNavigation.navigationSourceMode
                let td = nearbyNavigation.targetDistance
                let displayDistance: Float
                switch mode {
                case .gps:
                    displayDistance = distance
                default:
                    displayDistance = td > 0 ? td : distance
                }
                distanceBinding.wrappedValue = displayDistance
                bearingBinding.wrappedValue = bearingDegrees
                navigationSourceDebugBinding.wrappedValue = mode.debugLabel
                isOnScreenBinding.wrappedValue = onScreen
            }
        }

        /// Deterministic color from friend name (matches AvatarView palette).
        private var beaconColor: UIColor {
            let palette: [(CGFloat, CGFloat, CGFloat)] = [
                (0.33, 0.53, 0.89),
                (0.30, 0.69, 0.56),
                (0.82, 0.45, 0.32),
                (0.60, 0.40, 0.80),
                (0.88, 0.65, 0.23),
                (0.35, 0.65, 0.35),
                (0.75, 0.35, 0.55),
                (0.40, 0.60, 0.75),
            ]
            let hash = abs(friendName.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
            let c = palette[hash % palette.count]
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
        }

        deinit {
            timer?.invalidate()
        }
    }
}
