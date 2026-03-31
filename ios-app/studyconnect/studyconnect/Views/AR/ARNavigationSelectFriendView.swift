//
//  ARNavigationSelectFriendView.swift
//  studyconnect
//
//  Created by Copilot on 3/13/26.
//

import SwiftUI
import AVFoundation
import UIKit

/// Friend selection screen before launching AR navigation.
/// Lists nearby friends with radio-button selection, then checks camera
/// permission before navigating to ARNavigationView.  Handles all three
/// permission states: authorized, not-determined (requests access), denied
/// (directs to Settings).
struct ARNavigationSelectFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var friends: [UserProfile] = []
    @State private var service = FriendsService()       // @State per RULES.md (@Observable service)
    @State private var selectedFriendID: UUID? = nil   // single-select radio — only one friend at a time
    @State private var navigateToAR = false             // programmatic NavigationLink trigger

    @State private var showCameraPermissionAlert = false  // alert for first-time deny
    @State private var showCameraSettingsAlert = false    // alert directing user to Settings
    @State private var cameraPermissionMessage = ""

    private let permissionService = ARCameraPermissionService()  // records permission analytics

    var body: some View {
        VStack(spacing: 0) {
            // ── Header bar with back button ──
                Text("Select Friend to Navigate to")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        // Back chevron dismisses this screen
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
                        // Section header for nearby friends
                        Text("WITHIN 20 METERS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            // Radio-button style: tapping a row sets selectedFriendID,
                            // causing the checkmark to appear on that row only.
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

                // Hidden programmatic NavigationLink — activated by setting
                // navigateToAR = true after camera permission is confirmed.
                NavigationLink(
                    destination: destinationView,
                    isActive: $navigateToAR
                ) {
                    EmptyView()
                }
                .hidden()

                // "Start AR Navigation" CTA button — disabled until a friend is selected.
                // On tap, checks camera permission before navigating.
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
                        // Gradient when enabled, flat gray when disabled
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
            // Fetch-once pattern: only load if friends array is empty
            if friends.isEmpty {
                Task {
                    friends = await service.getSuggestedFriends()
                }
            }
        }
        // Alert shown when camera access was just denied by the user
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cameraPermissionMessage)
        }
        // Alert shown when camera was previously denied — offers a direct
        // link to the iOS Settings app so the user can re-enable the permission.
        .alert("Camera Access Denied", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                // UIApplication.openSettingsURLString deep-links to this app's Settings page
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(settingsURL)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To use AR navigation, enable camera access in Settings.")
        }
    }

    /// Checks AVCaptureDevice authorization and either navigates to AR,
    /// requests permission, or shows a Settings redirect alert.
    private func startARNavigation() {
        guard canStart else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            // Already granted — go straight to AR
            permissionService.recordPermissionGranted(true)
            navigateToAR = true

        case .notDetermined:
            // First-time prompt — system dialog appears
            AVCaptureDevice.requestAccess(for: .video) { granted in
                // Callback runs on arbitrary thread; dispatch to @MainActor
                // for SwiftUI state updates (per RULES.md async/await pattern)
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
            // Previously denied — can't re-prompt; direct to Settings
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

    /// @ViewBuilder destination: returns ARNavigationView for the selected
    /// friend, or EmptyView if none is selected (shouldn't happen since
    /// the button is disabled without a selection).
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
