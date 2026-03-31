//
//  SelectFriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

/// Step 1 of session scheduling: pick which friends to invite.
/// Shows suggested friends (currently = full friends list) with checkbox selection.
/// "Session Details" button pushes SessionDetailsView via FriendsRoute.
struct SelectFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []         // loaded from service
    @State private var service = FriendsService()
    @State private var selectedFriendIDs: Set<UUID> = []   // checked friends

    var body: some View {
        VStack(spacing: 0) {
            // Custom white top bar
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("Select Friends")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                // Invisible placeholder for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.clear)
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
        .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
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

