//
//  SessionAcceptedModal.swift
//  studyconnect
//
//

import SwiftUI

/// Confirmation popup shown after accepting a session invite.
/// Displays a green checkmark, the inviter’s name, and the session time.
/// Uses @Binding for isPresented so the parent (FriendsView) controls dismissal.
struct SessionAcceptedModal: View {
    @Binding var isPresented: Bool  // parent controls visibility
    let invitingUser: UserProfile   // who sent the invite
    let sessionDate: Date           // session start time for display

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                // Large green checkmark icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(Color(red: 0.34, green: 0.78, blue: 0.45))

                VStack(spacing: 8) {
                    // Headline confirmation
                    Text("Session Accepted!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    // Two-line subtitle with inviter name and session date
                    VStack(alignment: .center, spacing: 4) {
                        Text("You've joined \(invitingUser.displayTitle)'s study")
                        Text("session for \(dateLabel)")
                    }
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 24)

            // Close button — sets isPresented to false with animation,
            // dismissed by the parent view (FriendsView) which owns the binding.
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
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .background(Color.white) // Solid white keeps text crisp (no blur trasparency)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10) // Elevated card shadow
        .padding(.horizontal, 40) // Generous horizontal inset from screen edges
    }

    /// Formats the session date as "Today at 2:00 PM", "Tomorrow at 3:00 PM",
    /// or "Mar 25 at 4:00 PM" for further-out dates.
    private var dateLabel: String {
        let today = Calendar.current.startOfDay(for: Date())
        let sessionDay = Calendar.current.startOfDay(for: sessionDate)

        if sessionDay == today {
            return "Today at \(timeString)"
        } else if sessionDay == Calendar.current.date(byAdding: .day, value: 1, to: today) {
            return "Tomorrow at \(timeString)"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: sessionDate)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: sessionDate)
    }
}
