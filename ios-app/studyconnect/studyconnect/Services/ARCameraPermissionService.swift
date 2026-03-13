//
//  ARCameraPermissionService.swift
//  studyconnect
//
//

import Foundation

/// Handles camera permission tracking for AR navigation.
///
/// Currently this uses local storage so we only prompt the user once.
/// Replace `recordPermissionToBackend(...)` with a real API call when a backend endpoint is available.
final class ARCameraPermissionService {
    private let userDefaultsKey = "ARCameraPermissionGranted"

    /// Returns whether the user has granted camera permission in the past (according to persisted state).
    /// This is separate from the system camera authorization status.
    func hasGrantedPermissionPreviously() -> Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    /// Records the user decision locally and forwards it to the backend (stubbed for now).
    func recordPermissionGranted(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: userDefaultsKey)
        recordPermissionToBackend(granted: granted)
    }

    /// STUB: Replace with actual backend implementation so the service remembers the user's choice server-side.
    ///
    /// Example:
    /// - Use your networking layer to POST/PATCH an endpoint like `/api/user/preferences`.
    /// - Store the value in the user's profile so you can skip asking again on other devices.
    private func recordPermissionToBackend(granted: Bool) {
        // TODO: Implement backend persistence for camera permission.
        // e.g. APIClient.shared.patch("/me/preferences", body: ["ar_camera_access": granted])
        #if DEBUG
        print("[ARCameraPermissionService] (stub) recorded permission = \(granted)")
        #endif
    }
}
