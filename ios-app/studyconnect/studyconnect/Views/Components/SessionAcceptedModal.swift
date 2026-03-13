//
//  SessionAcceptedModal.swift
//  studyconnect
//
//

import SwiftUI

struct SessionAcceptedModal: View {
    @Binding var isPresented: Bool // Changed from Environment dismiss to Binding
    let invitingUser: UserProfile
    let sessionDate: Date

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(Color(red: 0.34, green: 0.78, blue: 0.45))

                VStack(spacing: 8) {
                    Text("Session Accepted!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

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
        .background(Color.white) // Use solid white to keep text sharp
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10) // Shadow makes it pop
        .padding(.horizontal, 40) // Space from screen edges
    }

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
