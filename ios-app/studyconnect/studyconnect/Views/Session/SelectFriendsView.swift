//
//  SelectFriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct SelectFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    @State private var selectedFriendIDs: Set<UUID> = []

    var body: some View {
        // ZStack needed: layering background color with title bar and scrollable content
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom white top bar - ZStack needed: centering title while positioning close button on the left
                ZStack {
                    Text("Select Friends")
                        .font(.system(size: 20, weight: .semibold))

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.white)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SUGGESTED")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        VStack(spacing: 12) {
                            ForEach(friends) { friend in
                                let isSelected = selectedFriendIDs.contains(friend.userId)
                                Button {
                                    toggleSelection(for: friend.userId)
                                } label: {
                                    FriendRowView(friend: friend, isSelected: isSelected)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }

                NavigationLink(value: FriendsRoute.sessionDetails(selectedProfiles)) {
                    HStack(spacing: 6) {
                        Text("Session Details")
                        Image(systemName: "arrow.right")
                    }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedFriendIDs.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .padding(.top, 8)
                }
                .disabled(selectedFriendIDs.isEmpty)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if friends.isEmpty {
                Task {
                    friends = await service.getSuggestedFriends()
                }
            }
        }
    }

    private var selectedProfiles: [UserProfile] {
        friends.filter { selectedFriendIDs.contains($0.userId) }
    }

    private func toggleSelection(for id: UUID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }
}

