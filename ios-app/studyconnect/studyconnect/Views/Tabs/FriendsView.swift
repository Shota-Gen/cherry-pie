//
//  FriendsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

/// Friends tab — central hub for friend management and session scheduling.
/// Owns a typed NavigationStack (NavigationPath + FriendsRoute enum) that
/// drives the entire session flow: SelectFriends → SessionDetails → FindAvailability.
/// Also shows pending session invites with accept/decline actions.
struct FriendsView: View {
    @State private var friends: [UserProfile] = []         // fetched friend list from Supabase
    @State private var service = FriendsService()          // handles friend CRUD operations
    @State private var path = NavigationPath()             // typed nav stack — drives the session scheduling flow
    @State private var pendingInvites: [SessionInvite] = [] // session invites awaiting user action
    @State private var inviteService = SessionInviteService()
    @State private var showAcceptedModal = false            // controls the "Session Accepted" confirmation popup
    @State private var acceptedInvite: SessionInvite?       // stores which invite was just accepted for the modal

    var body: some View {
        // NavigationStack with a typed NavigationPath so we can push/pop
        // programmatically using FriendsRoute enum values.
        // The session scheduling flow goes:
        //   SelectFriends → SessionDetails → FindAvailability
        // and "Back to Home" resets `path` to NavigationPath() to pop all.
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // ── Top bar: minus (delete friends), title, plus (add friend) ──
                HStack {
                    // Navigate to the remove-friends screen
                    NavigationLink(destination: DeleteFriendsView()) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Text("Friends")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    // Navigate to the add-friend-by-email screen
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
                        // ── "Create New Private Session" card ──
                        // Pushes the .selectFriends route onto the nav path,
                        // starting the 3-step session scheduling flow.
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

                        // ── Pending session invites section ──
                        // Only appears when there are unresolved invites.
                        // Each invite card has Accept and Decline buttons.
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
                                            // Save reference for the confirmation modal
                                            acceptedInvite = invite
                                            // Tell the backend this invite was accepted
                                            inviteService.acceptInvite(inviteId: invite.id)
                                            // Remove from local list immediately (optimistic UI)
                                            pendingInvites.removeAll { $0.id == invite.id }
                                            // Show the "Session Accepted!" modal with spring animation
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                showAcceptedModal = true
                                            }
                                        },
                                        onDecline: {
                                            // Tell backend to decline, remove from local list
                                            inviteService.declineInvite(inviteId: invite.id)
                                            pendingInvites.removeAll { $0.id == invite.id }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // ── Nearby friends list ──
                        // Sorted by distance (closest first); nil distances sink to bottom.
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
            // Blur the main content when the accepted-invite modal is showing
            .blur(radius: showAcceptedModal ? 10 : 0)
            .allowsHitTesting(!showAcceptedModal)  // disable interaction behind modal
            .onAppear {
                // Fetch friends and pending invites when tab comes into view
                Task {
                    friends = await service.getFriendsList()
                    pendingInvites = await inviteService.getPendingInvites()
                }
            }
            // Route-based navigation — maps FriendsRoute values to destination views.
            // This is how the session scheduling flow works:
            //   .selectFriends     → SelectFriendsView
            //   .sessionDetails    → SessionDetailsView (receives selected friend profiles)
            //   .findAvailability  → FindAvailabilityView (receives full SessionConfig)
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

            // ── Session Accepted modal overlay ──
            // Shown on top of the blurred content after accepting an invite.
            // ZStack layering: dimmed backdrop + centered modal card.
            if showAcceptedModal, let invite = acceptedInvite {
                // Semi-transparent backdrop — tapping it dismisses the modal
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { showAcceptedModal = false }
                    }

                // The actual confirmation card component
                SessionAcceptedModal(
                    isPresented: $showAcceptedModal,
                    invitingUser: invite.fromUser,
                    sessionDate: invite.startTime
                )
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(1)  // ensure modal renders above the backdrop
            }
        }
    }
}
