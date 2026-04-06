//
//  StudySpotService.swift
//  studyconnect
//
//  Handles fetching study spots and active users from the backend API.
//

import Foundation
import Auth

class StudySpotService {

    #if DEBUG && targetEnvironment(simulator)
    private let studySpotsURL = URL(string: "http://localhost:8080/studyspots/v1/public/")!
    private let activeUsersBaseURL = "http://localhost:8080/studyspots/v1/active-users/"
    #else
    // TODO: Replace with production API URL once deployed
    private let studySpotsURL = URL(string: "https://cherry-pie-production.up.railway.app/studyspots/v1/public/")!
    private let activeUsersBaseURL = "https://cherry-pie-production.up.railway.app/studyspots/v1/active-users/"
    #endif

    func getActiveUsers() async -> [ActiveStudyUser] {
        // Get the current user's ID to filter by friends
        guard let userId = SupabaseManager.shared.session?.user.id else {
            print("Failed to fetch active users: no logged-in user")
            return []
        }
        
        guard let url = URL(string: activeUsersBaseURL + userId.uuidString.lowercased()) else {
            print("Failed to fetch active users: invalid URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Failed to fetch active users: unexpected response")
                return []
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([ActiveStudyUser].self, from: data)
        } catch {
            print("Failed to fetch active users: \(error.localizedDescription)")
            return []
        }
    }

    func getStudySpots() async -> [StudySpot] {
        var request = URLRequest(url: studySpotsURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Failed to fetch study spots: unexpected response")
                return []
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)

                let formatterWithFractionalSeconds = ISO8601DateFormatter()
                formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                if let date = formatterWithFractionalSeconds.date(from: value) {
                    return date
                }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]

                if let date = formatter.date(from: value) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date string: \(value)")
            }

            return try decoder.decode([StudySpot].self, from: data)
        } catch {
            print("Failed to fetch study spots: \(error.localizedDescription)")
            return []
        }
    }
}
