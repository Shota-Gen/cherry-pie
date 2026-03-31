//
//  SessionInviteRowView.swift
//  studyconnect
//
//

import SwiftUI

/// Displays a single session invite with sender info, time range,
/// and Accept/Decline action buttons.  Used in FriendsView’s pending invites section.
struct SessionInviteRowView: View {
    let invite: SessionInvite
    let onAccept: () -> Void     // callback when user taps Accept
    let onDecline: () -> Void    // callback when user taps Decline

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Top row: sender avatar, name, subtitle, and relative timestamp ──
            HStack(spacing: 12) {
                // Sender's avatar
                AvatarView(name: invite.fromUser.displayTitle, imageURL: invite.fromUser.profileImage, size: 44)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.fromUser.displayTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Invited you to study")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Relative time since invite was created (e.g. "2m ago")
                Text(invite.createdTimeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // ── Time slot info line: clock icon + "Wednesday, 2:00 PM - 5:00 PM" ──
            HStack(spacing: 4) {
                Image(systemName: "clock.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))

                Text("\(invite.dayLabel), \(invite.timeRange)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }

            // ── Action buttons ──
            HStack(spacing: 10) {
                // Decline button: neutral gray, calls parent's onDecline closure
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

                // Accept button: prominent blue, calls parent's onAccept closure
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    SessionInviteRowView(
        invite: SessionInvite(
            id: UUID(),
            fromUser: UserProfile(userId: UUID(), displayName: "Leo Messi", email: "leo@umich.edu"),
            startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
            endTime: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date(),
            createdAt: Date(timeIntervalSinceNow: -120)
        ),
        onAccept: {},
        onDecline: {}
    )
}
