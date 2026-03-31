//
//  AvatarView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//

import SwiftUI

/// Shows a remote profile image if the URL is set, otherwise shows initials
/// on a deterministic color derived from a hash of the display name.
struct AvatarView: View {
    let name: String
    let imageURL: String
    var size: CGFloat = 42

    var body: some View {
        Group {
            // If we have a valid, non-empty URL string, attempt to load the remote image.
            // Otherwise fall back to the deterministic initials circle.
            if let url = URL(string: imageURL), !imageURL.isEmpty {
                // AsyncImage handles network fetch + caching automatically.
                // Phase-based switch lets us show the initials fallback for
                // loading/failure states instead of a blank placeholder.
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        // Covers .empty (loading) and .failure (network error).
                        // Initials keep the UI visually consistent while loading.
                        initialsView
                    }
                }
            } else {
                // No URL at all — show initials on a colored circle
                initialsView
            }
        }
        // Constrain to a square of `size` pts, then clip to a perfect circle
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    /// Colored circle with centered initials text.
    private var initialsView: some View {
        Circle()
            .fill(avatarColor)   // deterministic color from name hash
            .overlay(
                Text(initials)
                    // Font size scales with avatar size (36% of diameter)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    /// Extracts up to two initials from the display name.
    /// "Jawad Al-Sahlani" → "JA", "Sarah" → "S"
    private var initials: String {
        let words = name.split(separator: " ")
        let first = words.first?.prefix(1) ?? ""
        let second = words.dropFirst().first?.prefix(1) ?? ""
        return (first + second).uppercased()
    }

    // Deterministic color: hash the name into one of 8 pleasant hues.
    // Same name always produces the same color across the entire app.
    // Uses `&*` and `&+` (overflow operators) so large names don't trap.
    private var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.33, green: 0.53, blue: 0.89), // blue
            Color(red: 0.30, green: 0.69, blue: 0.56), // teal
            Color(red: 0.82, green: 0.45, blue: 0.32), // coral
            Color(red: 0.60, green: 0.40, blue: 0.80), // purple
            Color(red: 0.88, green: 0.65, blue: 0.23), // amber
            Color(red: 0.35, green: 0.65, blue: 0.35), // green
            Color(red: 0.75, green: 0.35, blue: 0.55), // rose
            Color(red: 0.40, green: 0.60, blue: 0.75), // steel blue
        ]
        let hash = abs(name.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
        return palette[hash % palette.count]
    }
}
