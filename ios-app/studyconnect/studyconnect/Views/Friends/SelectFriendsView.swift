//
//  SelectFriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct SelectFriendsView: View {
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    
    // This Set will store the IDs of the friends you tap on
    @State private var selectedFriendIDs: Set<UUID> = []
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95)
                .ignoresSafeArea()
            
            VStack {
                ScrollView {
                    VStack(spacing: 12) {
                        // FIXED: Using \.userId to identify each friend properly
                        ForEach(friends, id: \.userId) { friend in
                            FriendSelectionRow(
                                // FIXED: Pulling the actual name from your service!
                                name: friend.displayName,
                                isSelected: selectedFriendIDs.contains(friend.userId)
                            ) {
                                toggleSelection(for: friend.userId)
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // The "Next" Button
                NavigationLink(destination: FindAvailabilityView(selectedFriends: Array(selectedFriendIDs))) {
                    Text("Next")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedFriendIDs.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .disabled(selectedFriendIDs.isEmpty)
            }
        }
        .navigationTitle("Select Friends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            friends = service.getFriendsList()
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }
}

// A reusable row component for the selection list
struct FriendSelectionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(Text(name.prefix(1)).foregroundColor(.black))
                
                Text(name)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
    }
}
