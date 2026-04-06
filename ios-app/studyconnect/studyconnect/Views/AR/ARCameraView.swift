//
//  ARCameraView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreHaptics

struct ARCameraView: View {
    // Hardcoded test user (placeholder until UWB integration)
    private let testUser = UserProfile(
        userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        displayName: "Test Friend",
        email: "friend@example.com",
        profileImage: "profile_pic_url"
    )

    var body: some View {
        // ZStack: AR view fills screen with optional overlay controls on top
        ZStack(alignment: .top) {
            ARMovingFriendView(user: testUser)
        }
        .ignoresSafeArea()
    }
}

struct ARMovingFriendView: UIViewRepresentable {
    let user: UserProfile

    func makeCoordinator() -> Coordinator {
        Coordinator(user: user)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config)
        context.coordinator.setupFriendEntity(in: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    class Coordinator {
        let user: UserProfile
        var friendAnchor: AnchorEntity?
        var sphereEntity: ModelEntity?
        var updateSubscription: Cancellable?
        var hapticEngine: CHHapticEngine?
        var hasTriggeredCloseHaptic = false

        // Hardcoded friend world position (simulates UWB):
        // 3m forward (-Z), 1m right (+X), same height
        let friendWorldPosition = SIMD3<Float>(1.0, 0.0, -3.0)

        init(user: UserProfile) {
            self.user = user
            setupHaptics()
        }

        func setupHaptics() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {}
        }

        func setupFriendEntity(in arView: ARView) {
            if let anchor = friendAnchor {
                arView.scene.removeAnchor(anchor)
            }

            let sphereColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.85)
            let sphereMaterial = SimpleMaterial(color: sphereColor, roughness: 0.15, isMetallic: true)
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.15),
                materials: [sphereMaterial]
            )
            sphere.name = "FriendSphere"
            self.sphereEntity = sphere

            let billboard = makeBillboardEntity(for: user)
            billboard.position = SIMD3<Float>(0, 0.25, 0)
            sphere.addChild(billboard)

            // Anchor at a fixed world position — moves relative to camera as you walk/rotate
            let anchor = AnchorEntity(world: friendWorldPosition)
            anchor.addChild(sphere)
            arView.scene.addAnchor(anchor)
            self.friendAnchor = anchor

            // Use RealityKit scene subscription for per-frame updates (no Timer/RunLoop)
            updateSubscription = arView.scene.subscribe(
                to: SceneEvents.Update.self
            ) { [weak self] _ in
                self?.onSceneUpdate(arView: arView)
            }
        }

        // MARK: - Per-frame update: pulsing + haptics

        func onSceneUpdate(arView: ARView) {
            guard let sphere = sphereEntity,
                  let frame = arView.session.currentFrame else { return }

            let camCol = frame.camera.transform.columns.3
            let cameraPos = SIMD3<Float>(camCol.x, camCol.y, camCol.z)
            let distance = simd_distance(cameraPos, friendWorldPosition)

            // Pulse faster and larger as the user gets closer
            let time = Float(CACurrentMediaTime())
            let pulseSpeed: Float = max(2.0, 10.0 - distance * 2.0)
            let pulseAmount: Float = 1.0 + 0.15 * sin(time * pulseSpeed)
            sphere.scale = SIMD3<Float>(repeating: pulseAmount)

            // Haptic thud when within 1.5 m
            if distance <= 1.5, !hasTriggeredCloseHaptic {
                hasTriggeredCloseHaptic = true
                triggerThudHaptic()
            } else if distance > 1.5 {
                hasTriggeredCloseHaptic = false
            }
        }

        func triggerThudHaptic() {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)
            } catch {}
        }

        // MARK: - Billboard

        func makeBillboardEntity(for user: UserProfile) -> Entity {
            let size = CGSize(width: 180, height: 80)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor(white: 1, alpha: 0.85).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                let profileRect = CGRect(x: 10, y: 10, width: 60, height: 60)
                if let url = URL(string: user.profileImage),
                   let data = try? Data(contentsOf: url),
                   let img = UIImage(data: data) {
                    img.draw(in: profileRect)
                } else {
                    UIColor.gray.setFill()
                    ctx.cgContext.fillEllipse(in: profileRect)
                }

                let nameRect = CGRect(x: 80, y: 25, width: 90, height: 30)
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .left
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
                user.displayTitle.draw(in: nameRect, withAttributes: attrs)
            }

            guard let cgImage = image.cgImage else {
                return makeFallbackPlane()
            }

            let textureResource: TextureResource
            do {
                textureResource = try TextureResource.generate(
                    from: cgImage,
                    options: .init(semantic: .color)
                )
            } catch {
                return makeFallbackPlane()
            }

            var material = UnlitMaterial()
            material.baseColor = .texture(textureResource)
            let mesh = MeshResource.generatePlane(width: 0.18, height: 0.08)
            let plane = ModelEntity(mesh: mesh, materials: [material])
            plane.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            return plane
        }

        private func makeFallbackPlane() -> ModelEntity {
            var fallbackMaterial = UnlitMaterial()
            fallbackMaterial.baseColor = .color(.white)
            let plane = ModelEntity(
                mesh: .generatePlane(width: 0.18, height: 0.08),
                materials: [fallbackMaterial]
            )
            plane.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            return plane
        }

        deinit {
            updateSubscription?.cancel()
            hapticEngine?.stop()
        }
    }
}

import simd
extension float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }
}
