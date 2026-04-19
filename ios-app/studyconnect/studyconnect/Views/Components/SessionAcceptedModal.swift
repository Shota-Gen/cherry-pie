//
//  SessionAcceptedModal.swift
//  studyconnect
//
//

import SwiftUI

struct SessionAcceptedModal: View {
    @Binding var isPresented: Bool
    let invite: SessionInvite

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(Color(red: 0.34, green: 0.78, blue: 0.45))

                VStack(spacing: 6) {
                    Text("Session Accepted!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    Text("You've joined \(invite.fromUser.displayTitle)'s study session for \(dateLabel).")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 10) {
                detailRow(icon: "calendar", text: invite.displayTitle)

                if let location = invite.locationName, !location.isEmpty {
                    detailRow(
                        icon: "mappin.and.ellipse",
                        text: locationSummary(name: location, address: invite.locationAddress)
                    )
                }

                if let description = invite.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !description.isEmpty {
                    detailRow(icon: "text.alignleft", text: description, lineLimit: 4)
                }

                if let link = invite.meetingLink, let url = URL(string: link) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Join Google Meet")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(red: 0.96, green: 0.97, blue: 1.0))
            .cornerRadius(12)

            Button {
                withAnimation {
                    isPresented = false
                }
            } label: {
                Text("Close")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 32)
    }

    private func detailRow(icon: String, text: String, lineLimit: Int = 2) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
    }

    private func locationSummary(name: String, address: String?) -> String {
        guard let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty else {
            return name
        }
        return "\(name)\n\(address)"
    }

    private var dateLabel: String {
        let today = Calendar.current.startOfDay(for: Date())
        let sessionDay = Calendar.current.startOfDay(for: invite.startTime)

        if sessionDay == today {
            return "Today at \(timeString)"
        } else if sessionDay == Calendar.current.date(byAdding: .day, value: 1, to: today) {
            return "Tomorrow at \(timeString)"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: invite.startTime)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: invite.startTime)
    }
}
