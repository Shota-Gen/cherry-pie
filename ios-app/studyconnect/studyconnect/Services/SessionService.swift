//
//  SessionService.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/10/26.
//  Updated: Smart Scheduler integration (Google Calendar + Gemini)
//

import Foundation

class SessionService {

    // Use local Docker API on simulator, production Railway URL on device
    #if DEBUG && targetEnvironment(simulator)
    private let baseURL = "http://localhost:8080"
    #else
    private let baseURL = "https://cherry-pie-production.up.railway.app"
    #endif

    // MARK: - Smart Scheduler API

    /// Fetches AI-suggested study session slots from the backend.
    ///
    /// The backend queries Google Calendar FreeBusy for all participants,
    /// then uses Gemini LLM to find optimal meeting times.
    ///
    /// - Parameters:
    ///   - config: Session parameters (date range, duration, time window, friends)
    ///   - hostId: UUID of the signed-in user
    /// - Returns: Array of TimeSlot suggestions, ranked best-first
    func getSuggestedSlots(config: SessionConfig, hostId: UUID) async throws -> [TimeSlot] {
        let url = URL(string: "\(baseURL)/scheduler/suggest-times")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Build the search window from the config
        let cal = Calendar.current
        let windowStart = timeOnDay(config.earliestStart, day: config.startDate, cal: cal)
        let windowEnd = timeOnDay(config.latestEnd, day: config.endDate, cal: cal)

        let participantIds = [hostId.uuidString.lowercased()] +
            config.selectedFriends.map { $0.userId.uuidString.lowercased() }

        let body: [String: Any] = [
            "host_id": hostId.uuidString.lowercased(),
            "participant_ids": participantIds,
            "window_start": formatter.string(from: windowStart),
            "window_end": formatter.string(from: windowEnd),
            "duration_minutes": config.duration * 60, // config.duration is in hours
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SchedulerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ Smart Scheduler failed with status \(httpResponse.statusCode): \(responseBody)")
            throw SchedulerError.serverError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        let decoded = try JSONDecoder().decode(SuggestTimesAPIResponse.self, from: data)

        // Convert API response to TimeSlot models
        var friendMap = Dictionary(uniqueKeysWithValues:
            config.selectedFriends.map { ($0.userId.uuidString.lowercased(), $0) }
        )
        // Include the host so they appear in slot availability results
        friendMap[hostId.uuidString.lowercased()] = UserProfile(userId: hostId, displayName: "You", email: "")

        return decoded.slots.compactMap { slot -> TimeSlot? in
            guard let start = formatter.date(from: slot.start),
                  let end = formatter.date(from: slot.end) else {
                // Try without fractional seconds
                let fallbackFmt = ISO8601DateFormatter()
                fallbackFmt.formatOptions = [.withInternetDateTime]
                guard let start = fallbackFmt.date(from: slot.start),
                      let end = fallbackFmt.date(from: slot.end) else { return nil }

                let available = slot.available_user_ids.compactMap { friendMap[$0] }
                let busy = slot.busy_user_ids.compactMap { friendMap[$0] }
                return TimeSlot(id: UUID(), start: start, end: end,
                                availableFriends: available, busyFriends: busy)
            }

            let available = slot.available_user_ids.compactMap { friendMap[$0] }
            let busy = slot.busy_user_ids.compactMap { friendMap[$0] }
            return TimeSlot(id: UUID(), start: start, end: end,
                            availableFriends: available, busyFriends: busy)
        }
    }

    // MARK: - Fallback (Stub) Scheduler

    /// Local stub scheduler — used as a fallback when the API is unreachable.
    func getSuggestedSlotsLocal(config: SessionConfig) -> [TimeSlot] {
        let cal = Calendar.current
        var slots: [TimeSlot] = []
        let startDay = cal.startOfDay(for: config.startDate)
        let endDay   = cal.startOfDay(for: config.endDate)
        var currentDay = startDay

        while currentDay <= endDay {
            let windowStart = timeOnDay(config.earliestStart, day: currentDay, cal: cal)
            let windowEnd   = timeOnDay(config.latestEnd,     day: currentDay, cal: cal)
            let durationSec = TimeInterval(config.duration * 3600)

            var candidates: [Date] = []
            var t = windowStart
            while t.addingTimeInterval(durationSec) <= windowEnd {
                candidates.append(t)
                t = t.addingTimeInterval(1800)
            }

            if !candidates.isEmpty {
                let count = Int.random(in: 1...min(3, candidates.count))
                let chosen = candidates.shuffled().prefix(count).sorted()
                for start in chosen {
                    let busy = randomBusy(from: config.selectedFriends)
                    let busyIds = Set(busy.map(\.userId))
                    let available = config.selectedFriends.filter { !busyIds.contains($0.userId) }
                    slots.append(TimeSlot(id: UUID(), start: start,
                                         end: start.addingTimeInterval(durationSec),
                                         availableFriends: available, busyFriends: busy))
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = next
        }
        return slots
    }

    // MARK: - Store Google Token

    /// Sends the user's Google OAuth server auth code to the backend for token exchange and storage.
    func storeGoogleToken(userId: UUID, serverAuthCode: String, accessToken: String, googleEmail: String) async throws {
        let url = URL(string: "\(baseURL)/scheduler/store-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": userId.uuidString.lowercased(),
            "server_auth_code": serverAuthCode,
            "access_token": accessToken,
            "google_email": googleEmail,
            "scopes": [
                "https://www.googleapis.com/auth/calendar.freebusy",
                "https://www.googleapis.com/auth/calendar.events"
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ Token storage failed with status \(statusCode): \(responseBody)")
            throw SchedulerError.serverError(statusCode: statusCode, message: responseBody)
        }

        print("✅ Google token stored successfully for \(googleEmail)")
    }

    // MARK: - Create Session

    /// Create a study session and send invites via the backend API.
    func createSession(createdBy: UUID, spotId: UUID?, starts: Date, ends: Date, invitedUsers: [UUID],
                        title: String, locationName: String, description: String, addGoogleMeet: Bool) {
        Task {
            do {
                var components = URLComponents(string: "\(baseURL)/sessions/private")!
                components.queryItems = [URLQueryItem(name: "creator_id", value: createdBy.uuidString.lowercased())]

                guard let url = components.url else {
                    print("❌ Failed to build session URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                var body: [String: Any] = [
                    "title": title.isEmpty ? "Study Session" : title,
                    "starts_at": formatter.string(from: starts),
                    "ends_at": formatter.string(from: ends),
                    "invitee_ids": invitedUsers.map { $0.uuidString.lowercased() },
                    "add_google_meet": addGoogleMeet
                ]
                if !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body["location_name"] = locationName
                }
                if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body["description"] = description
                }
                if let spotId {
                    body["study_spot_id"] = spotId.uuidString.lowercased()
                }

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    print("✅ Session created successfully")
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("❌ Session creation failed with status \(statusCode): \(responseBody)")
                }
            } catch {
                print("❌ Session creation error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func timeOnDay(_ ref: Date, day: Date, cal: Calendar) -> Date {
        let h = cal.component(.hour,   from: ref)
        let m = cal.component(.minute, from: ref)
        return cal.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
    }

    private func randomBusy(from friends: [UserProfile]) -> [UserProfile] {
        guard friends.count > 1, Bool.random() else { return [] }
        let numBusy = Int.random(in: 1...min(2, friends.count - 1))
        return Array(friends.shuffled().prefix(numBusy))
    }
}

// MARK: - Scheduler Error

enum SchedulerError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from the scheduling server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// MARK: - API Response Models

struct SuggestTimesAPIResponse: Codable {
    let slots: [SlotAPIResponse]
    let participants_queried: Int
    let participants_with_calendar: Int
    let used_llm: Bool?
}

struct SlotAPIResponse: Codable {
    let start: String
    let end: String
    let available_user_ids: [String]
    let busy_user_ids: [String]
    let score: Double
    let reason: String?
}
