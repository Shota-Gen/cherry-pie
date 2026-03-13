//
//  FriendRowView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/11/26.
//


import SwiftUI

/// Shared friend list row used in FriendsView and SelectFriendsView.
/// Pass `isSelected` to enable selection mode (checkmark + blue border).
struct FriendRowView: View {
    let friend: UserProfile
    var isSelected: Bool? = nil

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
                    .padding(.trailing, isSelected != nil ? 8 : 0)
            }

            if let selected = isSelected {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(selected ? .blue : Color.gray.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: (isSelected == true) ? 2 : 0)
        )
    }
}
