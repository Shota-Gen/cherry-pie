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
    @State private var pendingInvites: [SessionInvite] = []
    @State private var inviteService = SessionInviteService()
    @State private var showAcceptedModal = false
    @State private var acceptedInvite: SessionInvite?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // 1. Fixed Background Color
                Color(red: 0.95, green: 0.95, blue: 0.95)
                    .ignoresSafeArea()
                
                // 2. Main Content Wrapper
                VStack(spacing: 0) {
                    // White top bar
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
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
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

                            if !pendingInvites.isEmpty {
                                Text("PENDING INVITES")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                    .padding(.top, 12)

                                VStack(spacing: 12) {
                                    ForEach(pendingInvites) { invite in
                                        SessionInviteRowView(
                                            invite: invite,
                                            onAccept: {
                                                acceptedInvite = invite
                                                inviteService.acceptInvite(inviteId: invite.id)
                                                pendingInvites.removeAll { $0.id == invite.id }
                                                // Trigger modal with animation
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    showAcceptedModal = true
                                                }
                                            },
                                            onDecline: {
                                                inviteService.declineInvite(inviteId: invite.id)
                                                pendingInvites.removeAll { $0.id == invite.id }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
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
                // --- THIS BLURS ONLY THE BACKGROUND CONTENT ---
                .blur(radius: showAcceptedModal ? 10 : 0)
                .allowsHitTesting(!showAcceptedModal) // Disable interaction when modal is up

                // 3. Custom Modal Overlay
                if showAcceptedModal, let invite = acceptedInvite {
                    // Dimmer overlay
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation { showAcceptedModal = false }
                        }

                    // Modal view
                    SessionAcceptedModal(
                        isPresented: $showAcceptedModal,
                        invitingUser: invite.fromUser,
                        sessionDate: invite.startTime
                    )
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .onAppear {
                Task {
                    friends = await service.getFriendsList()
                    pendingInvites = await inviteService.getPendingInvites()
                }
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
