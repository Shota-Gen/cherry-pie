//
//  AddFriendView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

/// Allows the user to add a friend by entering their UID.
/// On success, displays an animated modal overlay confirming the request was sent.
struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss          // pops this view off the navigation stack
    @State private var uid: String = ""           // text field binding for the friend's UID
    @State private var showSuccess = false         // triggers the animated confirmation overlay
    @State private var service = FriendsService()  // handles the friend-add API call

    var body: some View {
        VStack(spacing: 0) {
            // ── Custom navigation bar ──
            // We hide the system nav bar and build our own so the back chevron,
            // title, and invisible placeholder are perfectly centered.
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("Add Friend")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                // Invisible chevron balances the HStack so the title stays centered
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .padding()
            .background(Color.white)

            VStack(alignment: .leading, spacing: 20) {
                // Instructional text explaining how UIDs work
                Text("Enter your friend's unique user ID (UID) to send them a request. You can find your UID in your profile settings.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 4)

                // ── UID text input field ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter their UID")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)

                    TextField("e.g. 84924562", text: $uid)
                        .autocapitalization(.none)       // UIDs are case-sensitive
                        .disableAutocorrection(true)     // prevent autocorrect mangling the ID
                        .padding(12)
                        .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                        .cornerRadius(10)
                }

                // ── Send request button ──
                // Disabled while UID is blank; turns blue when text is entered.
                // The Task{} block calls FriendsService.addFriend which posts to
                // the Supabase friends table, then shows the success modal.
                Button {
                    Task {
                        await service.addFriend(id: uid)
                        print("Friend request sent")
                        showSuccess = true  // trigger the overlay animation
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Send Friend Request")
                        Image(systemName: "paperplane.fill")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    // Gray when disabled, blue when enabled
                    .background(uid.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(uid.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Spacer()
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
        // ── Success modal overlay ──
        // Shown after the friend request is sent. Uses a ZStack (justified:
        // genuine layering of dimmed backdrop + centered card).
        .overlay(alignment: .center) {
            if showSuccess {
                // ZStack required for layering modal overlay with semi-transparent dimming background behind content
                ZStack {
                    // Dimmed backdrop
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    // Confirmation card with checkmark, message, and dismiss button
                    VStack(spacing: 20) {
                        // Green checkmark icon in a light green circle
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                            }

                        Text("Request Sent!")
                            .font(.title2.weight(.bold))

                        Text("We'll let them know you want to connect.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        // Tapping "Back to Friends" dismisses both the modal and this view
                        Button {
                            showSuccess = false
                            dismiss()
                        } label: {
                            Text("Back to Friends")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))  // scale+fade entrance
                }
            }
        }
        .navigationBarHidden(true)  // using custom nav bar
        // Animate the overlay appearance/disappearance
        .animation(.easeInOut(duration: 0.22), value: showSuccess)
    }
}

#Preview {
    NavigationStack {
        AddFriendView()
    }
}


