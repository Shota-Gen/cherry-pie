//
//  SessionServiceTests.swift
//  studyconnectTests
//
//  Integration tests for SessionService against the local Docker backend.
//  Requires: docker compose up --build (backend on localhost:8080)
//

import Testing
import Foundation
@testable import studyconnect

struct SessionServiceTests {

    private let baseURL = "http://127.0.0.1:8080"

    // MARK: - Helpers

    /// Creates a test user via the backend API and returns their user_id.
    private func createTestUser(name: String, email: String) async throws -> String {
        let url = URL(string: "\(baseURL)/users/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "display_name": name,
            "email": email,
            "password": "testpass123"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        // 201 = created, 409 = already exists (reuse)
        if httpResponse.statusCode == 409 {
            // User already exists — look them up via Supabase
            // For simplicity, we'll fail with a descriptive message
            throw TestError(message: "Test user \(email) already exists. Use unique emails or clean the DB.")
        }

        #expect(httpResponse.statusCode == 201, "Expected 201, got \(httpResponse.statusCode)")

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["user_id"] as! String
    }

    /// Calls POST /sessions/private mimicking what SessionService.createSession does.
    private func createSessionViaAPI(
        creatorId: String,
        inviteeIds: [String],
        startsAt: Date,
        endsAt: Date
    ) async throws -> (statusCode: Int, body: [String: Any]) {
        var components = URLComponents(string: "\(baseURL)/sessions/private")!
        components.queryItems = [URLQueryItem(name: "creator_id", value: creatorId)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "title": "Study Session",
            "starts_at": formatter.string(from: startsAt),
            "ends_at": formatter.string(from: endsAt),
            "invitee_ids": inviteeIds
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (httpResponse.statusCode, json)
    }

    // MARK: - Tests

    @Test func createSessionReturns201WithValidUsers() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let creatorId = try await createTestUser(
            name: "Creator \(timestamp)",
            email: "creator_\(timestamp)@test.umich.edu"
        )
        let inviteeId = try await createTestUser(
            name: "Invitee \(timestamp)",
            email: "invitee_\(timestamp)@test.umich.edu"
        )

        let starts = Date().addingTimeInterval(3600)     // 1 hour from now
        let ends   = starts.addingTimeInterval(7200)     // 3 hours from now

        let result = try await createSessionViaAPI(
            creatorId: creatorId,
            inviteeIds: [inviteeId],
            startsAt: starts,
            endsAt: ends
        )

        #expect(result.statusCode == 201, "Expected 201, got \(result.statusCode): \(result.body)")
        #expect(result.body["session_id"] != nil, "Response should contain session_id")
        #expect(result.body["session_type"] as? String == "private")

        // Verify members
        let members = result.body["members"] as? [[String: Any]] ?? []
        #expect(members.count == 2, "Should have 2 members (creator + invitee)")

        let statuses = Set(members.compactMap { $0["status"] as? String })
        #expect(statuses.contains("accepted"), "Creator should be accepted")
        #expect(statuses.contains("pending"), "Invitee should be pending")
    }

    @Test func createSessionRejects404ForFakeInvitees() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let creatorId = try await createTestUser(
            name: "Creator2 \(timestamp)",
            email: "creator2_\(timestamp)@test.umich.edu"
        )

        let fakeInviteeId = UUID().uuidString.lowercased()

        let starts = Date().addingTimeInterval(3600)
        let ends   = starts.addingTimeInterval(7200)

        let result = try await createSessionViaAPI(
            creatorId: creatorId,
            inviteeIds: [fakeInviteeId],
            startsAt: starts,
            endsAt: ends
        )

        #expect(result.statusCode == 404, "Should return 404 for non-existent invitee, got \(result.statusCode)")
    }

    @Test func respondToInviteWorks() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let creatorId = try await createTestUser(
            name: "Creator3 \(timestamp)",
            email: "creator3_\(timestamp)@test.umich.edu"
        )
        let inviteeId = try await createTestUser(
            name: "Invitee3 \(timestamp)",
            email: "invitee3_\(timestamp)@test.umich.edu"
        )

        let starts = Date().addingTimeInterval(3600)
        let ends   = starts.addingTimeInterval(7200)

        // Create the session
        let createResult = try await createSessionViaAPI(
            creatorId: creatorId,
            inviteeIds: [inviteeId],
            startsAt: starts,
            endsAt: ends
        )
        #expect(createResult.statusCode == 201)
        let sessionId = createResult.body["session_id"] as! String

        // Accept the invite
        let respondURL = URL(string: "\(baseURL)/sessions/\(sessionId)/respond")!
        var request = URLRequest(url: respondURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let respondBody: [String: String] = ["user_id": inviteeId, "action": "accepted"]
        request.httpBody = try JSONSerialization.data(withJSONObject: respondBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200, "Accept should return 200")

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["status"] as? String == "accepted")
    }
}

private struct TestError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
