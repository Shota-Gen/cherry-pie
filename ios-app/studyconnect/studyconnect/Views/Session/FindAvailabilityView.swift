//
//  FindAvailabilityView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI
import Auth

struct FindAvailabilityView: View {
    var selectedFriends: [UserProfile]
    @Binding var path: NavigationPath

    @EnvironmentObject var supabase: SupabaseManager
    @State private var service = SessionService()

    @State private var studySpots: [StudySpot] = []
    @State private var selectedSpotId: UUID? = nil
    @State private var startTime = Date().roundedToNextHour()
    @State private var endTime = Date().roundedToNextHour().addingTimeInterval(3600)
    @State private var sessionGap: TimeInterval = 3600
    @State private var sessionSent = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                Form {
                    Section("Session Time") {
                        DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .onChange(of: startTime) { _, newStart in
                                endTime = newStart.addingTimeInterval(sessionGap)
                            }

                        DatePicker("End", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                            .onChange(of: endTime) { _, newEnd in
                                sessionGap = max(newEnd.timeIntervalSince(startTime), 0)
                            }
                    }

                    Section("Study Spot") {
                        if studySpots.isEmpty {
                            Text("Loading spots...")
                                .foregroundColor(.gray)
                        } else {
                            Picker("Location", selection: $selectedSpotId) {
                                Text("None").tag(nil as UUID?)
                                ForEach(studySpots) { spot in
                                    Text(spot.name).tag(spot.spotId as UUID?)
                                }
                            }
                        }
                    }

                    Section("Invites") {
                        ForEach(selectedFriends) { friend in
                            Text(friend.displayTitle)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                Button {
                    guard let spotId = selectedSpotId,
                          let userId = supabase.session?.user.id else { return }
                    service.createSession(
                        createdBy: userId,
                        spotId: spotId,
                        starts: startTime,
                        ends: endTime,
                        invitedUsers: selectedFriends.map(\.userId)
                    )
                    sessionSent = true
                } label: {
                    Text(selectedFriends.count == 1 ? "Send Invite" : "Send Invites")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedSpotId != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .disabled(selectedSpotId == nil)
            }

            // Dimmed overlay + confirmation card
            if sessionSent {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text(selectedFriends.count == 1 ? "Invite sent successfully!" : "Invites sent successfully!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Your friends have been notified")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button {
                        sessionSent = false
                        path = NavigationPath()
                    } label: {
                        Text("Back to Home")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
                .padding(32)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(.horizontal, 32)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessionSent)
        .navigationTitle("Find Availability")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            studySpots = service.getStudySpots()
            selectedSpotId = studySpots.first?.spotId
        }
    }
}

private extension Date {
    func roundedToNextHour() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: self)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return cal.date(from: comps) ?? self
    }
}

#Preview {
    FindAvailabilityView(selectedFriends: [], path: .constant(NavigationPath()))
        .environmentObject(SupabaseManager.shared)
}
