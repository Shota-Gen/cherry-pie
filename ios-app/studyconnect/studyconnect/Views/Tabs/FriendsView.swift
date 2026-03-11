//
//  FriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct FriendsView: View {
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Gray background
                Color(red: 0.95, green: 0.95, blue: 0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // White top bar with Friends title and Add button
                    HStack {
                        NavigationLink(destination: DeleteFriendsView()) {
                            Image(systemName: "minus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                        }

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
                            NavigationLink(value: FriendsRoute.selectFriends) {
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
                                ForEach(friends.sorted { ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude) }) { friend in
                                    FriendRowView(friend: friend)
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
            .navigationDestination(for: FriendsRoute.self) { route in
                switch route {
                case .selectFriends:
                    SelectFriendsView()
                case .sessionDetails(let profiles):
                    SessionDetailsView(selectedFriends: profiles)
                case .findAvailability(let config):
                    FindAvailabilityView(config: config, path: $path)
                }
            }
        }
    }
}

#Preview {
    FriendsView()
}
