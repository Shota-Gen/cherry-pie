//
//  ARNavigationView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit
import Combine

struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(edges: .all)

            ARViewContainer(friend: friend)
                .ignoresSafeArea(edges: .all)

            VStack(spacing: 0) {
                topBar
            .padding(.top, 6)

                Spacer()

                targetCard
                    .padding(.bottom, 60)
            }
        }
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

            Text("12m")
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = true

        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        config.planeDetection = []
        config.worldAlignment = .gravity

        arView.session.run(config, options: [])

        // Place a simple billboard in front of the user representing the friend.
        let anchor = AnchorEntity(world: [0, 0, -1.2])

        let planeSize: Float = 0.28
        let plane = ModelEntity(mesh: .generatePlane(width: planeSize, height: planeSize), materials: [SimpleMaterial(color: .white, isMetallic: false)])
        anchor.addChild(plane)
        arView.scene.addAnchor(anchor)

        // Make the plane always face the camera.
        let subscription = arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            let cameraPosition = arView.cameraTransform.translation
            plane.look(at: cameraPosition, from: plane.position, relativeTo: nil)
        }
        context.coordinator.subscriptions.append(subscription)

        Task { [weak arView] in
            guard let cgImage = billboardImage(for: friend).cgImage else { return }

            let options = TextureResource.CreateOptions(semantic: .color)
            if let texture = try? await TextureResource.generate(from: cgImage, options: options) {
                var material = SimpleMaterial(color: .white, isMetallic: false)
                material.baseColor = .texture(texture)
                plane.model?.materials = [material]
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) { }

    class Coordinator {
        var subscriptions: [Cancellable] = []
    }

    private func billboardImage(for friend: UserProfile) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            UIColor(white: 0, alpha: 0.45).setFill()
            ctx.fill(rect)

            let cardRect = rect.insetBy(dx: 32, dy: 40)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 40)
            UIColor(white: 1, alpha: 0.18).setFill()
            cardPath.fill()

            let targetText = "TARGET"
            let targetAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 42),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let targetSize = targetText.size(withAttributes: targetAttributes)
            let targetOrigin = CGPoint(x: cardRect.midX - targetSize.width / 2, y: cardRect.minY + 24)
            targetText.draw(at: targetOrigin, withAttributes: targetAttributes)

            let avatarDiameter: CGFloat = 180
            let avatarOrigin = CGPoint(x: cardRect.midX - avatarDiameter / 2, y: targetOrigin.y + targetSize.height + 18)
            let avatarRect = CGRect(origin: avatarOrigin, size: CGSize(width: avatarDiameter, height: avatarDiameter))
            let avatarPath = UIBezierPath(ovalIn: avatarRect)
            UIColor(white: 1, alpha: 0.25).setFill()
            avatarPath.fill()

            let initials: String = {
                let parts = friend.displayTitle.split(separator: " ")
                let first = parts.first?.prefix(1) ?? ""
                let second = parts.dropFirst().first?.prefix(1) ?? ""
                return (first + second).uppercased()
            }()

            let initialsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let initialsSize = initials.size(withAttributes: initialsAttributes)
            let initialsOrigin = CGPoint(x: avatarRect.midX - initialsSize.width / 2, y: avatarRect.midY - initialsSize.height / 2)
            initials.draw(at: initialsOrigin, withAttributes: initialsAttributes)

            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let name = friend.displayTitle
            let nameSize = name.size(withAttributes: nameAttributes)
            let nameOrigin = CGPoint(x: cardRect.midX - nameSize.width / 2, y: avatarRect.maxY + 18)
            name.draw(at: nameOrigin, withAttributes: nameAttributes)
        }
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

#Preview {
    ARNavigationView(friend: UserProfile(userId: UUID(), displayName: "Sarah Jenkins", email: "sarah@umich.edu", studySpot: "Student Union", distanceMiles: 0.1))
}
