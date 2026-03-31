//
//  DeleteFriendsView.swift
//  studyconnect
//
//  Created by Ayah Chahine on 3/11/26.
//


//
//  DeleteFriendView.swift
//  studyconnect
//
//  Created by Ayah Chahine on 3/11/26.
//

import SwiftUI

/// Multi-select interface for removing friends.  Shows all friends with red
/// minus-circle selection indicators.  "Delete Selected" button removes
/// mutual friendships (both directions) and dismisses the view.
struct DeleteFriendsView: View {
    @Environment(\.dismiss) private var dismiss             // pops back to FriendsView
    @State private var friends: [UserProfile] = []           // all friends, loaded on appear
    @State private var service = FriendsService()            // handles delete API call
    @State private var selectedFriendIDs: Set<UUID> = []     // multi-select: tracks which friends are marked for deletion

    var body: some View {
        VStack(spacing: 0) {
            // ── Custom top bar: Cancel + title ──
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Delete Friends")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                // Hidden duplicate of "Cancel" to center the title via HStack
                Text("Cancel").font(.system(size: 16)).hidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 12) {
                            // Friends sorted by distance (closest first).
                            // Each row is a DeleteFriendRowView with a red
                            // minus-circle that fills when tapped/selected.
                            ForEach(friends.sorted {
                                ($0.distanceMiles ?? .greatestFiniteMagnitude) <
                                ($1.distanceMiles ?? .greatestFiniteMagnitude)
                            }) { friend in
                                let isSelected = selectedFriendIDs.contains(friend.userId)

                                // Tapping a row toggles its selection state
                                Button {
                                    toggleSelection(for: friend.userId)
                                } label: {
                                    DeleteFriendRowView(friend: friend, isSelected: isSelected)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                }

                // ── Delete button pinned at bottom ──
                // Disabled (gray) when nothing is selected; red when ≥ 1 friend selected.
                // Shows count in parentheses when friends are selected.
                Button {
                    deleteSelectedFriends()
                } label: {
                    Text(selectedFriendIDs.isEmpty
                         ? "Delete Selected"
                         : "Delete Selected (\(selectedFriendIDs.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedFriendIDs.isEmpty ? Color.gray : Color.red)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .padding(.top, 8)
                }
                .disabled(selectedFriendIDs.isEmpty)
                
            .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
        }
        .navigationBarHidden(true) // using custom nav bar above
        .onAppear {
            // Load the full friends list when the view appears
            Task {
                friends = await service.getFriendsList()
            }
        }
    }

    /// Toggles a friend's UUID in/out of the selectedFriendIDs set
    private func toggleSelection(for id: UUID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }

    /// Calls FriendsService.deleteFriends to remove mutual friendships
    /// for all selected UUIDs, then dismisses back to the friends list.
    private func deleteSelectedFriends() {
        Task {
            await service.deleteFriends(ids: selectedFriendIDs)
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        DeleteFriendsView()
    }
}
