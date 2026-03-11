//
//  DeleteFriendRowView.swift
//  studyconnect
//

import SwiftUI

struct DeleteFriendRowView: View {
    let friend: UserProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: friend.displayTitle, imageURL: friend.profileImage)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(friend.studySpot.isEmpty ? "Not Found" : friend.studySpot)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if let dist = friend.distanceMiles {
                Text(String(format: "%.1f mi", dist))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
            }

            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 1.5)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)

                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
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
