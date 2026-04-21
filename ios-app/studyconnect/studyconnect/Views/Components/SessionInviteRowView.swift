//
//  SessionInviteRowView.swift
//  studyconnect
//
//

import SwiftUI

struct SessionInviteRowView: View {
    let invite: SessionInvite
    let onAccept: () -> Void
    let onDecline: () -> Void


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(name: invite.fromUser.displayTitle, imageURL: invite.fromUser.profileImage, size: 44)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.fromUser.displayTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Invited you to \(invite.displayTitle)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(invite.createdTimeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                detailRow(
                    icon: "clock.fill",
                    text: "\(invite.dayLabel), \(invite.timeRange)"
                )

                if let location = invite.locationName, !location.isEmpty {
                    detailRow(
                        icon: "mappin.and.ellipse",
                        text: location
                    )
                }

                if let description = invite.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !description.isEmpty {
                    detailRow(
                        icon: "text.alignleft",
                        text: description,
                        lineLimit: 3
                    )
                }
            }

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
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func detailRow(icon: String, text: String, lineLimit: Int = 2) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                .frame(width: 14, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
    }


}

#Preview {
    SessionInviteRowView(
        invite: SessionInvite(
            id: UUID(),
            fromUser: UserProfile(userId: UUID(), displayName: "Leo Messi", email: "leo@umich.edu"),
            startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
            endTime: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date(),
            createdAt: Date(timeIntervalSinceNow: -120),
            title: "EECS 498 Cram Session",
            description: "Reviewing final practice problems and going over weak spots before tomorrow's exam.",
            locationName: "Shapiro Undergraduate Library",
            meetingLink: nil
        ),
        onAccept: {},
        onDecline: {}
    )
}
