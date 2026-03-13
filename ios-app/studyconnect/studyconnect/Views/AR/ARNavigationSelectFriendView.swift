//
//  ARNavigationSelectFriendView.swift
//  studyconnect
//
//  Created by Copilot on 3/13/26.
//

import SwiftUI

struct ARNavigationSelectFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    @State private var selectedFriendID: UUID? = nil
    @State private var navigateToAR = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Select Friend to Navigate to")
                        .font(.system(size: 18, weight: .semibold))

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                ScrollView {                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WITHIN 20 METERS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            ForEach(friends) { friend in
                                Button {
                                    selectedFriendID = friend.userId
                                } label: {
                                    ARNavigationFriendRowView(friend: friend, isSelected: selectedFriendID == friend.userId)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                NavigationLink(
                    destination: destinationView,
                    isActive: $navigateToAR
                ) {
                    EmptyView()
                }
                .hidden()

                Button {
                    navigateToAR = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 26, height: 26)
                            Image(systemName: "arkit")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Start AR Navigation")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: canStart ? [Color(red: 0.22, green: 0.61, blue: 0.99), Color(red: 0.44, green: 0.70, blue: 1.00)] : [Color.gray.opacity(0.55), Color.gray.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
                    .padding(.horizontal)
                    .padding(.bottom, 22)
                }
                .disabled(!canStart)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if friends.isEmpty {
                friends = service.getSuggestedFriends()
            }
        }
    }

    private var canStart: Bool {
        selectedFriendID != nil
    }

    private var selectedFriend: UserProfile? {
        guard let id = selectedFriendID else { return nil }
        return friends.first { $0.userId == id }
    }

    @ViewBuilder
    private var destinationView: some View {
        if let friend = selectedFriend {
            ARNavigationView(friend: friend)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        ARNavigationSelectFriendView()
    }
}
