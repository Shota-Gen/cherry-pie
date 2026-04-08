//
//  ARNavigationSelectFriendView.swift
//  studyconnect
//
//  Created by Copilot on 3/13/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct ARNavigationSelectFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // TODO: potentially delete? we are discovering nearby users not friends
    @State private var friends: [UserProfile] = [
        // dummy data
//        UserProfile(userId: UUID(), displayName: "Alice Johnson",  email: "alice@umich.edu", studySpot: "Engineering Building", distanceMiles: 0.2),
//        UserProfile(userId: UUID(), displayName: "Bob Smith",      email: "bob@umich.edu",   studySpot: "Library",             distanceMiles: 0.5)
    ]
    @State private var service = FriendsService()
    @State private var selectedFriendID: UUID? = nil
    @State private var navigateToAR = false

    @State private var showCameraPermissionAlert = false
    @State private var showCameraSettingsAlert = false
    @State private var cameraPermissionMessage = ""

    private let permissionService = ARCameraPermissionService()
    
    @Binding var nearbyNavigation: NearbyNavigationService?

    var body: some View {
        VStack(spacing: 0) {
            // Header
                Text("Select Friend to Navigate to")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
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
                    }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                ScrollView {                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WITHIN 10 METERS")
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
                    startARNavigation()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arkit")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.25)))

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
        .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if friends.isEmpty {
                Task {
                    friends = await service.getSuggestedFriends()
                }
            }
        }
        .onDisappear() {
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cameraPermissionMessage)
        }
        .alert("Camera Access Denied", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(settingsURL)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To use AR navigation, enable camera access in Settings.")
        }
    }

    private func startARNavigation() {
        guard canStart else { return }
        nearbyNavigation!.targetUser = selectedFriend

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionService.recordPermissionGranted(true)
            navigateToAR = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                // Use MainActor to update UI state from camera permission callback
                Task { @MainActor in
                    permissionService.recordPermissionGranted(granted)
                    if granted {
                        navigateToAR = true
                    } else {
                        cameraPermissionMessage = "We need camera access to show AR navigation."
                        showCameraPermissionAlert = true
                    }
                }
            }

        case .denied, .restricted:
            cameraPermissionMessage = "When camera access is denied, AR navigation cannot run. Please update permissions in Settings."
            showCameraSettingsAlert = true

        @unknown default:
            cameraPermissionMessage = "Unable to determine camera permission status."
            showCameraPermissionAlert = true
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
            ARNavigationView(friend: friend, nearbyNavigation: $nearbyNavigation)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        ARNavigationSelectFriendView(nearbyNavigation: .constant(NearbyNavigationService(user: UserProfile(userId: UUID(), displayName: "Unknown User",  email: "unknown", studySpot: "Unknown", distanceMiles: 0.0))))
    }
}
