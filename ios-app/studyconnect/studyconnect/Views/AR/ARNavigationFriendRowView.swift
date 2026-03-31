//
//  ARNavigationFriendRowView.swift
//  studyconnect
//
//  Created by Copilot on 3/13/26.
//

import SwiftUI

/// Styled row for the AR friend selection list.  Shows avatar, name,
/// distance in meters, and a blue checkmark when selected.
struct ARNavigationFriendRowView: View {
    let friend: UserProfile
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text(distanceText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? Color.blue : Color.gray.opacity(0.5))
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
        )
    }

    private var distanceText: String {
        guard let miles = friend.distanceMiles else { return "Unknown" }
        let meters = Int((miles * 1609.34).rounded())
        return "\(meters)m away"
    }
}

#Preview {
    ARNavigationFriendRowView(friend: UserProfile(userId: UUID(), displayName: "Sarah Jenkins", email: "sarah@umich.edu", studySpot: "Student Union", distanceMiles: 0.0075), isSelected: true)
}
