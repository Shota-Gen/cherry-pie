//
//  FriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct FriendsView: View {
    @State private var friends: [Friend] = []
    @State private var service = FriendsService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gray background
                Color(red: 0.95, green: 0.95, blue: 0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // White top bar with Friends title and Add button
                    HStack {
                        Spacer()
                        
                        Text("Friends")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Spacer()
                        
                        NavigationLink(destination: AddFriendView()) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    
                    // Scrollable friends list with top button
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Create New Session Button
                            NavigationLink(destination: SelectFriendsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Create New")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.black)
                                        Text("Private Session")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            
                            Text("Nearby Friends")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 12)
                            
                            VStack(spacing: 12) {
                                ForEach(friends.sorted { $0.distance < $1.distance }) { friend in
                                    HStack(spacing: 12) {
                                        // Icon
                                        Image(systemName: friend.icon)
                                            .font(.system(size: 42))
                                            .foregroundColor(.blue)
                                            .frame(width: 50)
                                        
                                        // Name and Location
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.name)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                            Text(friend.location)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        // Distance in bright blue
                                        Text(String(format: "%.1f mi", friend.distance))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0)) // Bright map blue
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .onAppear {
                friends = service.getFriendsList()
            }
        }
    }
}

#Preview {
    FriendsView()
}
