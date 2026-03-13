//
//  ARNavigationView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import RealityKit
import ARKit

struct ARNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: UserProfile

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(edges: .all)

            ARViewContainer()
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
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = true

        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        config.planeDetection = []
        config.worldAlignment = .gravity

        arView.session.run(config, options: [])

        // A simple virtual indicator can be added later. For now, show camera feed.
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) { }
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
