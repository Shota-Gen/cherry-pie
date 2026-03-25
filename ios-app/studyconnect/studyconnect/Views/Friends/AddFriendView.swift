//
//  AddFriendView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var uid: String = ""
    @State private var showSuccess = false
    @State private var service = FriendsService()

    var body: some View {
        // ZStack needed: layering background color with modal content and overlay for success state
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea()

            VStack(spacing: 0) {
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
                    // Invisible placeholder for symmetry
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.clear)
                }
                .padding()
                .background(Color.white)

                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    Text("Enter your friend's unique user ID (UID) to send them a request. You can find your UID in your profile settings.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 4)

                    // UID input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter their UID")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.gray)

                        TextField("e.g. 84924562", text: $uid)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                            .cornerRadius(10)
                    }

                    // Send button
                    Button {
                        Task {
                            await service.addFriend(id: uid)
                            print("Friend request sent")
                            showSuccess = true
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
                        .background(uid.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(uid.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                Spacer()
            }

            // Dimmed overlay + success card
            if showSuccess {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
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
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.22), value: showSuccess)
    }
}

#Preview {
    NavigationStack {
        AddFriendView()
    }
}


