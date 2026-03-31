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
    @Environment(\.dismiss) private var dismiss             // pops back to FriendsView
    @State private var friends: [UserProfile] = []         // full suggested friends list from service
    @State private var service = FriendsService()          // fetches friend data from Supabase
    @State private var selectedFriendIDs: Set<UUID> = []   // tracks which friends are checked

    var body: some View {
        VStack(spacing: 0) {
            // ── Custom white top bar with centered title ──
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
                // Invisible placeholder mirrors the back button to keep title centered
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

                    // Friend rows with checkbox selection.
                    // FriendRowView receives isSelected to show a
                    // filled/unfilled checkmark circle and a blue border.
                    VStack(spacing: 12) {
                        ForEach(friends) { friend in
                            let isSelected = selectedFriendIDs.contains(friend.userId)
                            // Tapping the row toggles this friend's selection
                            Button {
                                toggleSelection(for: friend.userId)
                            } label: {
                                FriendRowView(friend: friend, isSelected: isSelected)
                            }
                            .buttonStyle(.plain)  // prevent default blue tint
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }

            // ── "Session Details" button pinned at bottom ──
            // Uses NavigationLink(value:) to push the next step onto
            // FriendsView's NavigationPath via FriendsRoute.sessionDetails.
            // Disabled (gray) when no friends are selected.
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
        .navigationBarHidden(true)  // using custom nav bar
        .onAppear {
            // Only fetch once — subsequent returns from the back button
            // keep the existing list so selections aren't lost
            if friends.isEmpty {
                Task {
                    friends = await service.getSuggestedFriends()
                }
            }
        }
    }

    /// Filters the full friends list down to just the selected profiles,
    /// to pass to the next screen (SessionDetailsView).
    private var selectedProfiles: [UserProfile] {
        friends.filter { selectedFriendIDs.contains($0.userId) }
    }

    /// Toggles a friend in/out of the selection set
    private func toggleSelection(for id: UUID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }
}

