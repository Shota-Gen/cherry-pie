//  FriendRequestRowView.swift
//  studyconnect
//
//

import SwiftUI

/// Displays a single friend request with sender info and Accept/Decline buttons.
struct FriendRequestRowView: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: sender avatar, name, subtitle, and relative timestamp
            HStack(spacing: 12) {
                AvatarView(name: request.fromUser?.displayTitle ?? "Unknown", imageURL: request.fromUser?.profileImage ?? "", size: 44)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.fromUser?.displayTitle ?? "Unknown")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Sent you a friend request")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(request.createdTimeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onDecline()
                } label: {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(8)
                }
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
