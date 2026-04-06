import SwiftUI
import RealityKit
import ARKit
import UIKit
import Combine
import CoreHaptics

struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile
    @State private var distanceToTarget: Float = 5.0
    @State private var bearingToTarget: Float = 0
    @State private var deviceHeading: Float = 0
    @State private var isHeadingAvailable = false
    @State private var shouldAutoDismiss = false

    private var distanceColor: Color {
        if distanceToTarget <= 1.5 { return .green }
        if distanceToTarget <= 4.0 { return Color(red: 0.22, green: 0.61, blue: 0.99) }
        return .white.opacity(0.9)
    }

    private var distanceLabel: String {
        if distanceToTarget < 1 {
            return String(format: "%.1fm", distanceToTarget)
        }
        return "\(Int(distanceToTarget))m away"
    }

    var body: some View {
        // ZStack: AR camera fills screen, overlaid with minimal HUD
        ZStack {
            Color.black.ignoresSafeArea(edges: .all)

            ARViewContainer(
                friend: friend,
                distanceToTarget: $distanceToTarget,
                bearingToTarget: $bearingToTarget,
                deviceHeading: $deviceHeading,
                isHeadingAvailable: $isHeadingAvailable,
                shouldAutoDismiss: $shouldAutoDismiss
            )
            .ignoresSafeArea(edges: .all)

            VStack(spacing: 0) {
                topBar.padding(.top, 6)
                Spacer()
                bottomPill.padding(.bottom, 44)
            }
        }
        .statusBarHidden()
        .onChange(of: shouldAutoDismiss) { _, close in
            if close { dismiss() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("FINDING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))

                Text(friend.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(distanceLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(distanceColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.black.opacity(0.7)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .padding(.horizontal, 8)
    }

    // MARK: - Bottom pill

    private var bottomPill: some View {
        HStack(spacing: 14) {
            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Nearby")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button { dismiss() } label: {
                Text("End")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Color.black.opacity(0.75)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - AR View Container

private struct ARViewContainer: UIViewRepresentable {
    let friend: UserProfile
    @Binding var distanceToTarget: Float
    @Binding var bearingToTarget: Float
    @Binding var deviceHeading: Float
    @Binding var isHeadingAvailable: Bool
    @Binding var shouldAutoDismiss: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(friend: friend)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // World tracking with scene reconstruction for ghost walls
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)

        // Semi-transparent ghost material on reconstructed walls/floors
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        }

        let coordinator = context.coordinator
        coordinator.setupFriendEntity(in: arView)
        coordinator.startTracking(
            arView: arView,
            distanceBinding: $distanceToTarget,
            bearingBinding: $bearingToTarget,
            headingBinding: $deviceHeading,
            isHeadingAvailableBinding: $isHeadingAvailable,
            autoDismissBinding: $shouldAutoDismiss
        )
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    class Coordinator {
        let friend: UserProfile
        var friendAnchor: AnchorEntity?
        var beaconRoot: Entity?
        var sphereEntity: ModelEntity?
        var glowRingEntity: ModelEntity?
        var arrowEntity: ModelEntity?
        var updateSubscription: Cancellable?
        var hapticEngine: CHHapticEngine?
        var hasTriggeredCloseHaptic = false

        // Hardcoded world position (simulates smoothed UWB + barometer vector)
        let targetWorldPosition = SIMD3<Float>(1.0, 0.0, -3.0)

        // Smoothed beacon position (simulates UWB vector smoothing)
        private var smoothedAnchorPos = SIMD3<Float>(1.0, 0.0, -3.0)

        // Sphere sizing
        private let sphereRadius: Float = 0.4

        init(friend: UserProfile) {
            self.friend = friend
            setupHaptics()
        }

        // MARK: - Haptics

        private func setupHaptics() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {}
        }

        private func triggerThudHaptic() {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)
            } catch {}
        }

        // MARK: - 3D Beacon (purgatory object — ignores depth)

        func setupFriendEntity(in arView: ARView) {
            if let anchor = friendAnchor {
                arView.scene.removeAnchor(anchor)
            }

            let root = Entity()
            root.name = "BeaconRoot"

            // --- Profile sphere: large, with centered avatar texture ---
            let avatarTexture = renderAvatarTexture(name: friend.displayTitle, size: 1024)
            let sphere: ModelEntity
            if let texture = avatarTexture {
                var mat = UnlitMaterial()
                mat.baseColor = .texture(texture)
                sphere = ModelEntity(mesh: .generateSphere(radius: sphereRadius), materials: [mat])
            } else {
                let color = avatarUIColor(for: friend.displayTitle)
                let mat = SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)
                sphere = ModelEntity(mesh: .generateSphere(radius: sphereRadius), materials: [mat])
            }
            sphere.name = "FriendSphere"
            self.sphereEntity = sphere
            root.addChild(sphere)

            // --- Name label below sphere ---
            let label = makeNameLabel()
            label.position = SIMD3<Float>(0, -(sphereRadius + 0.10), 0)
            root.addChild(label)

            // --- Distance label (updates each frame via a child entity) ---
            let distLabel = makeDistanceLabel(distance: 5.0)
            distLabel.name = "DistanceLabel"
            distLabel.position = SIMD3<Float>(0, -(sphereRadius + 0.20), 0)
            root.addChild(distLabel)

            // --- Small directional arrow below labels ---
            let arrow = makeArrowEntity()
            arrow.position = SIMD3<Float>(0, -(sphereRadius + 0.32), 0)
            root.addChild(arrow)
            self.arrowEntity = arrow

            // --- Glow ring at sphere equator ---
            let ringColor = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.25)
            var ringMat = UnlitMaterial()
            ringMat.baseColor = .color(ringColor)
            ringMat.blending = .transparent(opacity: .init(floatLiteral: 0.25))
            let ringSize = sphereRadius * 2.8
            let ring = ModelEntity(
                mesh: .generatePlane(width: ringSize, depth: ringSize, cornerRadius: ringSize / 2),
                materials: [ringMat]
            )
            ring.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            ring.position = SIMD3<Float>(0, -(sphereRadius + 0.01), 0)
            root.addChild(ring)
            self.glowRingEntity = ring

            self.beaconRoot = root

            let anchor = AnchorEntity(world: targetWorldPosition)
            anchor.addChild(root)
            arView.scene.addAnchor(anchor)
            self.friendAnchor = anchor
        }

        // MARK: - Avatar texture (full-canvas fill, centered initials)

        private func renderAvatarTexture(name: String, size: Int) -> TextureResource? {
            let cgSize = CGSize(width: size, height: size)
            let renderer = UIGraphicsImageRenderer(size: cgSize)
            let image = renderer.image { ctx in
                let rect = CGRect(origin: .zero, size: cgSize)

                // Fill entire canvas with avatar color (sphere UV maps the full image)
                let bgColor = avatarUIColor(for: name)
                bgColor.setFill()
                ctx.fill(rect)

                // Centered initials
                let words = name.split(separator: " ")
                let first = words.first?.prefix(1) ?? ""
                let second = words.dropFirst().first?.prefix(1) ?? ""
                let initials = (first + second).uppercased()

                let fontSize = CGFloat(size) * 0.35
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let textSize = (initials as NSString).size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (cgSize.width - textSize.width) / 2,
                    y: (cgSize.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                initials.draw(in: textRect, withAttributes: attrs)
            }

            guard let cgImage = image.cgImage else { return nil }
            return try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        }

        private func avatarUIColor(for name: String) -> UIColor {
            let palette: [UIColor] = [
                UIColor(red: 0.33, green: 0.53, blue: 0.89, alpha: 1),
                UIColor(red: 0.30, green: 0.69, blue: 0.56, alpha: 1),
                UIColor(red: 0.82, green: 0.45, blue: 0.32, alpha: 1),
                UIColor(red: 0.60, green: 0.40, blue: 0.80, alpha: 1),
                UIColor(red: 0.88, green: 0.65, blue: 0.23, alpha: 1),
                UIColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1),
                UIColor(red: 0.75, green: 0.35, blue: 0.55, alpha: 1),
                UIColor(red: 0.40, green: 0.60, blue: 0.75, alpha: 1),
            ]
            let hash = abs(name.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
            return palette[hash % palette.count]
        }

        // MARK: - Name label

        private func makeNameLabel() -> Entity {
            let textSize = CGSize(width: 512, height: 72)
            let renderer = UIGraphicsImageRenderer(size: textSize)
            let image = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(origin: .zero, size: textSize))

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let drawRect = CGRect(x: 0, y: 10, width: textSize.width, height: textSize.height - 10)
                friend.displayTitle.draw(in: drawRect, withAttributes: attrs)
            }

            guard let cgImage = image.cgImage,
                  let tex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            else { return Entity() }

            var mat = UnlitMaterial()
            mat.baseColor = .texture(tex)
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.95))
            let mesh = MeshResource.generatePlane(width: 0.45, height: 0.065)
            let label = ModelEntity(mesh: mesh, materials: [mat])
            label.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            return label
        }

        // MARK: - Distance label

        private func makeDistanceLabel(distance: Float) -> Entity {
            let textSize = CGSize(width: 256, height: 48)
            let renderer = UIGraphicsImageRenderer(size: textSize)
            let distText = distance < 1 ? String(format: "%.1fm", distance) : "\(Int(distance))m"
            let image = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(origin: .zero, size: textSize))

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.9),
                    .paragraphStyle: paragraph
                ]
                distText.draw(in: CGRect(x: 0, y: 6, width: textSize.width, height: textSize.height - 6), withAttributes: attrs)
            }

            guard let cgImage = image.cgImage,
                  let tex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            else { return Entity() }

            var mat = UnlitMaterial()
            mat.baseColor = .texture(tex)
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.9))
            let mesh = MeshResource.generatePlane(width: 0.22, height: 0.04)
            let label = ModelEntity(mesh: mesh, materials: [mat])
            label.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            return label
        }

        // MARK: - Arrow indicator

        private func makeArrowEntity() -> ModelEntity {
            let arrowSize = CGSize(width: 96, height: 96)
            let renderer = UIGraphicsImageRenderer(size: arrowSize)
            let image = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(origin: .zero, size: arrowSize))

                let path = UIBezierPath()
                path.move(to: CGPoint(x: 48, y: 80))
                path.addLine(to: CGPoint(x: 16, y: 24))
                path.addLine(to: CGPoint(x: 80, y: 24))
                path.close()
                UIColor(red: 0.3, green: 0.65, blue: 1.0, alpha: 0.8).setFill()
                path.fill()
            }

            guard let cgImage = image.cgImage,
                  let tex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            else {
                var fb = UnlitMaterial()
                fb.baseColor = .color(.clear)
                return ModelEntity(mesh: .generatePlane(width: 0.08, height: 0.08), materials: [fb])
            }

            var mat = UnlitMaterial()
            mat.baseColor = .texture(tex)
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.8))
            let arrow = ModelEntity(mesh: .generatePlane(width: 0.08, height: 0.08), materials: [mat])
            arrow.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            return arrow
        }

        // MARK: - Per-frame tracking

        func startTracking(
            arView: ARView,
            distanceBinding: Binding<Float>,
            bearingBinding: Binding<Float>,
            headingBinding: Binding<Float>,
            isHeadingAvailableBinding: Binding<Bool>,
            autoDismissBinding: Binding<Bool>
        ) {
            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                self?.onFrameUpdate(
                    arView: arView,
                    distanceBinding: distanceBinding,
                    bearingBinding: bearingBinding,
                    headingBinding: headingBinding,
                    isHeadingAvailableBinding: isHeadingAvailableBinding,
                    autoDismissBinding: autoDismissBinding
                )
            }
        }

        private func onFrameUpdate(
            arView: ARView,
            distanceBinding: Binding<Float>,
            bearingBinding: Binding<Float>,
            headingBinding: Binding<Float>,
            isHeadingAvailableBinding: Binding<Bool>,
            autoDismissBinding: Binding<Bool>
        ) {
            guard let frame = arView.session.currentFrame,
                  let anchor = friendAnchor else { return }

            let cam = frame.camera.transform
            let cameraPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)
            let distance = simd_distance(cameraPos, targetWorldPosition)

            // Direction vectors
            let deltaVector = targetWorldPosition - cameraPos
            let forward = SIMD3<Float>(-cam.columns.2.x, -cam.columns.2.y, -cam.columns.2.z)
            let right = SIMD3<Float>(cam.columns.0.x, cam.columns.0.y, cam.columns.0.z)
            let up = SIMD3<Float>(cam.columns.1.x, cam.columns.1.y, cam.columns.1.z)
            let forwardDist = simd_dot(deltaVector, forward)
            let rightDist = simd_dot(deltaVector, right)
            let bearing = atan2(rightDist, forwardDist) * 180 / .pi
            let heading = atan2(forward.x, -forward.z) * 180 / .pi

            Task { @MainActor in
                distanceBinding.wrappedValue = distance
                bearingBinding.wrappedValue = bearing
                headingBinding.wrappedValue = heading
                isHeadingAvailableBinding.wrappedValue = true
            }

            // --- Clamp beacon to viewport edges when target is off-screen ---
            let projDir = simd_length(deltaVector) > 0.001 ? simd_normalize(deltaVector) : forward
            let dotForward = simd_dot(projDir, forward)

            let clampDist: Float = 2.8
            let isOnScreen = dotForward > 0.35

            let desiredPos: SIMD3<Float>
            if isOnScreen {
                desiredPos = targetWorldPosition
            } else {
                let flatDelta = SIMD2<Float>(simd_dot(deltaVector, right), simd_dot(deltaVector, up))
                let flatLen = simd_length(flatDelta)
                let normFlat: SIMD2<Float> = flatLen > 0.001
                    ? flatDelta / flatLen
                    : SIMD2<Float>(1, 0)

                let edgeFraction: Float = 0.5
                let offsetRight = normFlat.x * edgeFraction
                let offsetUp = normFlat.y * edgeFraction

                desiredPos = cameraPos
                    + forward * clampDist
                    + right * (offsetRight * clampDist)
                    + up * (offsetUp * clampDist)
            }

            // Smooth position (simulates smoothed UWB + barometer vectors)
            let smoothing: Float = 0.10
            smoothedAnchorPos = smoothedAnchorPos + (desiredPos - smoothedAnchorPos) * smoothing
            anchor.position = smoothedAnchorPos

            // Billboard: rotate beacon root to face camera
            if let root = beaconRoot {
                let lookDir = cameraPos - smoothedAnchorPos
                let yaw = atan2(lookDir.x, lookDir.z)
                root.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            }

            // Gentle pulse — amplitude and speed increase as user gets closer
            if let sphere = sphereEntity {
                let time = Float(CACurrentMediaTime())
                // Speed: 1.5 Hz far away → 4 Hz at 1.5 m
                let pulseSpeed: Float = min(4.0, max(1.5, 6.0 - distance))
                // Amplitude: ±3% far → ±6% close
                let pulseAmp: Float = min(0.06, max(0.03, 0.08 - distance * 0.01))
                let pulseScale: Float = 1.0 + pulseAmp * sin(time * pulseSpeed * 2 * .pi)
                sphere.scale = SIMD3<Float>(repeating: pulseScale)
            }

            // Glow ring pulse (slightly offset phase for depth feel)
            if let ring = glowRingEntity {
                let time = Float(CACurrentMediaTime())
                let ringPulse: Float = 1.0 + 0.08 * sin(time * 2.0 * .pi + 1.0)
                ring.scale = SIMD3<Float>(repeating: ringPulse)
            }

            // Arrow bobbing
            if let arrow = arrowEntity {
                let time = Float(CACurrentMediaTime())
                let bob: Float = 0.015 * sin(time * 2.5)
                arrow.position.y = -(sphereRadius + 0.32) + bob
            }

            // Haptic thud + auto-dismiss at ≤ 1.5 m
            if distance <= 1.5, !hasTriggeredCloseHaptic {
                hasTriggeredCloseHaptic = true
                triggerThudHaptic()
                // Close the session after a short delay so the user feels the haptic
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    autoDismissBinding.wrappedValue = true
                }
            } else if distance > 2.0 {
                // Reset with hysteresis so it doesn't re-trigger immediately
                hasTriggeredCloseHaptic = false
            }
        }

        deinit {
            updateSubscription?.cancel()
            hapticEngine?.stop()
        }
    }
}
