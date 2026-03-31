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

struct DeleteFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    @State private var selectedFriendIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
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
                
                // Balance the Cancel button width
                Text("Cancel").font(.system(size: 16)).hidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(friends.sorted {
                                ($0.distanceMiles ?? .greatestFiniteMagnitude) <
                                ($1.distanceMiles ?? .greatestFiniteMagnitude)
                            }) { friend in
                                let isSelected = selectedFriendIDs.contains(friend.userId)

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
        .navigationBarHidden(true)
        .onAppear {
            Task {
                friends = await service.getFriendsList()
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }

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
