//
//  DeleteFriendRowView.swift
//  studyconnect
//

import SwiftUI

/// Friend row variant for the delete flow.  Shows a red minus-circle button
/// that fills when selected.  Used in DeleteFriendsView.
struct DeleteFriendRowView: View {
    let friend: UserProfile
    let isSelected: Bool   // red circle fills when true

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with initials fallback (shared component)
            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                // Friend's display name
                Text(friend.displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Study spot or fallback text
                Text(friend.studySpot.isEmpty ? "Not Found" : friend.studySpot)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Distance in miles (omitted if nil)
            if let dist = friend.distanceMiles {
                Text(String(format: "%.1f mi", dist))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
            }

            // Red minus-circle toggle:
            // • Unselected: red outline circle with a red minus icon
            // • Selected: filled red circle with white minus icon
            // Parent view toggles isSelected in a Set<UUID>.
            Circle()
                .stroke(Color.red, lineWidth: 1.5)
                .frame(width: 24, height: 24)
                .overlay {
                    if isSelected {
                        // Filled state — solid red with white minus
                        Circle()
                            .fill(Color.red)
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // Outline-only state — red minus on transparent background
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 12) {
        DeleteFriendRowView(
            friend: UserProfile(
                userId: UUID(),
                displayName: "Alice Johnson",
                email: "alice@umich.edu",
                studySpot: "Engineering Building",
                distanceMiles: 0.2
            ),
            isSelected: false
        )

        DeleteFriendRowView(
            friend: UserProfile(
                userId: UUID(),
                displayName: "Bob Smith",
                email: "bob@umich.edu",
                studySpot: "Library",
                distanceMiles: 0.5
            ),
            isSelected: true
        )
    }
    .padding()
    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
}
