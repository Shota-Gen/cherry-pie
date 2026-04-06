//
//  FriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

import Foundation
import SwiftUI
import Auth

struct FriendsView: View {
    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()
    @State private var path = NavigationPath()
    @State private var pendingInvites: [SessionInvite] = []
    @State private var inviteService = SessionInviteService()
    @State private var showAcceptedModal = false
    @State private var acceptedInvite: SessionInvite?
    @State private var incomingRequests: [FriendRequest] = []
    @State private var friendRequestService = FriendRequestService()
    @State private var currentUserId: UUID? = nil // For sender/receiver logic

    var body: some View {
        NavigationStack(path: $path) {
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
                        // --- INCOMING FRIEND REQUESTS SECTION ---
                        if !incomingRequests.isEmpty {
                            Text("FRIEND REQUESTS")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 12)

                            VStack(spacing: 12) {
                                ForEach(incomingRequests) { request in
                                    // If current user is the receiver and request is pending, show Accept/Decline
                                    if let myId = currentUserId, request.toUser.userId == myId && request.status == .pending {
                                        FriendRequestRowView(
                                            request: request,
                                            onAccept: {
                                                Task {
                                                    await friendRequestService.acceptRequest(requestId: request.id)
                                                    incomingRequests.removeAll { $0.id == request.id }
                                                }
                                            },
                                            onDecline: {
                                                Task {
                                                    await friendRequestService.rejectRequest(requestId: request.id)
                                                    incomingRequests.removeAll { $0.id == request.id }
                                                }
                                            }
                                        )
                                    } else if let myId = currentUserId, request.fromUser.userId == myId {
                                        // If current user is the sender, show status (pending/accepted/rejected)
                                        HStack {
                                            AvatarView(name: request.toUser.displayTitle, imageURL: request.toUser.profileImage, size: 44)
                                                .frame(width: 44, height: 44)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(request.toUser.displayTitle)
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                Text("Friend request status: \(request.status.rawValue.capitalized)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Text(request.createdTimeAgo)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
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
                
                Spacer()
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
            .blur(radius: showAcceptedModal ? 10 : 0)
            .allowsHitTesting(!showAcceptedModal)
            .onAppear {
                // --- TEST PROTOTYPE: Hardcoded incoming friend request for UI preview ---
                let myId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                let senderId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
                let me = UserProfile(userId: myId, displayName: "Test User (You)", email: "me@umich.edu")
                let sender = UserProfile(userId: senderId, displayName: "Jane Doe", email: "jane@umich.edu")
                currentUserId = myId
                incomingRequests = [
                    FriendRequest(
                        id: UUID(),
                        fromUser: sender,
                        toUser: me,
                        createdAt: Date(timeIntervalSinceNow: -300),
                        status: .pending
                    )
                ]
                // --- END TEST PROTOTYPE ---
                Task {
                    friends = await service.getFriendsList()
                    pendingInvites = await inviteService.getPendingInvites()
                    // Uncomment below to use real backend:
                    // currentUserId = SupabaseManager.shared.session?.user.id
                    // incomingRequests = await friendRequestService.getIncomingRequests()
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

            // Custom Modal Overlay
            if showAcceptedModal, let invite = acceptedInvite {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { showAcceptedModal = false }
                    }

                SessionAcceptedModal(
                    isPresented: $showAcceptedModal,
                    invitingUser: invite.fromUser,
                    sessionDate: invite.startTime
                )
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}
