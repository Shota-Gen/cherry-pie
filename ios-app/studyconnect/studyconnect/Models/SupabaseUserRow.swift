import Foundation

/// Codable representation of a row in `public.users`.
/// Uses snake_case CodingKeys to match Supabase column names.
struct SupabaseUserRow: Codable, Hashable {
    var userId: UUID
    var displayName: String?
    var email: String?
    var deviceId: String?
    var isInvisible: Bool?
    var lastKnownLat: Double?
    var lastKnownLng: Double?
    var currentFloor: Int?
    var createdAt: Date?
    var profileImage: String?
    var studySpot: String?
    var major: String?
    var universityYear: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case email
        case deviceId = "device_id"
        case isInvisible = "is_invisible"
        case lastKnownLat = "last_known_lat"
        case lastKnownLng = "last_known_lng"
        case currentFloor = "current_floor"
        case createdAt = "created_at"
        case profileImage = "profile_image"
        case studySpot = "study_spot"
        case major
        case universityYear = "university_year"
    }
}

extension SupabaseUserRow {
    init(from profile: UserProfile) {
        self.userId = profile.userId
        self.displayName = profile.displayName
        self.email = profile.email
        self.deviceId = profile.deviceId
        self.isInvisible = profile.isInvisible
        self.lastKnownLat = profile.lastKnownLat
        self.lastKnownLng = profile.lastKnownLng
        self.currentFloor = profile.currentFloor
        self.createdAt = profile.createdAt
        self.profileImage = profile.profileImage
        self.studySpot = profile.studySpot
        self.major = profile.major
        self.universityYear = profile.universityYear
    }

    func toUserProfile() -> UserProfile {
        UserProfile(
            userId: userId,
            displayName: displayName ?? "",
            email: email ?? "",
            profileImage: profileImage ?? "",
            studySpot: studySpot ?? "",
            major: major ?? "",
            universityYear: universityYear,
            deviceId: deviceId,
            isInvisible: isInvisible ?? false,
            lastKnownLat: lastKnownLat,
            lastKnownLng: lastKnownLng,
            currentFloor: currentFloor ?? 1,
            createdAt: createdAt,
            distanceMiles: nil
        )
    }
}

