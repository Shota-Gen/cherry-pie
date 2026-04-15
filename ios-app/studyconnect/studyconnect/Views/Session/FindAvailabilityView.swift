//
//  FindAvailabilityView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//  Updated: Smart Scheduler integration (async API + loading/error states)
//

import SwiftUI
import Auth

struct FindAvailabilityView: View {
    var config: SessionConfig
    @Binding var path: NavigationPath

    @Environment(\.supabaseManager) var supabase
    @State private var service = SessionService()
    @State private var slots: [TimeSlot] = []
    @State private var selectedSlot: TimeSlot? = nil
    @State private var sessionSent = false
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var usedLLM = false

    // Group slots by calendar day, sorted chronologically
    private var slotsByDay: [(day: Date, slots: [TimeSlot])] {
        var dict: [Date: [TimeSlot]] = [:]
        for slot in slots {
            let day = Calendar.current.startOfDay(for: slot.start)
            dict[day, default: []].append(slot)
        }
        return dict.keys.sorted().map { day in
            (day: day, slots: dict[day]!.sorted { $0.start < $1.start })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Info card ─────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INVITING")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            stackedAvatars
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("DURATION")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Text("\(config.duration) \(config.duration == 1 ? "Hour" : "Hours")")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)

                    // ── Smart Scheduler badge ───────────────────────
                    if !isLoading && !slots.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: usedLLM ? "brain.fill" : "clock.fill")
                                .font(.caption)
                                .foregroundColor(usedLLM ? .purple : .orange)
                            Text(usedLLM ? "AI-Powered Suggestions" : "Quick Suggestions")
                                .font(.caption.weight(.medium))
                                .foregroundColor(usedLLM ? .purple : .orange)
                            Spacer()
                            if !usedLLM {
                                Text("Calendar not linked")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(usedLLM
                                      ? Color.purple.opacity(0.08)
                                      : Color.orange.opacity(0.08))
                        )
                    }

                    // ── Slot list / loading / error ───────────────────
                    if isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Analyzing calendars…")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                                Text("Checking availability for \(config.selectedFriends.count) friend\(config.selectedFriends.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Couldn't find times")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await fetchSlots() }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                            Button("Use Offline Mode") {
                                slots = service.getSuggestedSlotsLocal(config: config)
                                errorMessage = nil
                                usedLLM = false
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Couldn't find times")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await fetchSlots() }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                            Button("Use Offline Mode") {
                                slots = service.getSuggestedSlotsLocal(config: config)
                                errorMessage = nil
                                usedLLM = false
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal)
                    } else if slots.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Slots Found")
                                .font(.headline)
                            Text("Try expanding your date range or time window")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(slotsByDay, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                dayHeader(for: group.day)
                                ForEach(group.slots) { slot in
                                    slotCard(slot)
                                }
                            }
                        }
                    }

                    Color.clear.frame(height: 80)
                }
                .padding()

                // ── Send bar ───────────────────────────────────────────────
                HStack {
                    Button { sendInvites() } label: {
                        HStack(spacing: 8) {
                            Text(config.selectedFriends.count == 1 ? "Send Invite" : "Send Invites")
                            Image(systemName: "envelope.fill")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedSlot != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .disabled(selectedSlot == nil)
                }
                .background(Color.white)
            }
        }
        .overlay {
            if sessionSent {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text(config.selectedFriends.count == 1 ? "Invite sent successfully!" : "Invites sent successfully!")
                        .font(.title2.weight(.bold))
                    Text("Your friends have been notified")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button {
                        sessionSent = false
                        path = NavigationPath()
                    } label: {
                        Text("Back to Home")
                            .font(.headline.weight(.semibold))
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
        .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: sessionSent)
        .navigationTitle("Find Availability")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchSlots()
        }
    }

    // MARK: - Fetch Slots (Smart Scheduler)

    private func fetchSlots() async {
        isLoading = true
        errorMessage = nil
        errorMessage = nil

        guard let userId = supabase.session?.user.id else {
            // No auth — fall back to local
            slots = service.getSuggestedSlotsLocal(config: config)
            isLoading = false
            return
        }

        do {
            let result = try await service.getSuggestedSlots(config: config, hostId: userId)
            slots = result
            usedLLM = true
            isLoading = false
        } catch {
            print("⚠️ Smart Scheduler failed, trying local fallback: \(error.localizedDescription)")
            // Fallback to local stub scheduling
            slots = service.getSuggestedSlotsLocal(config: config)
            usedLLM = false
            isLoading = false
        }
    }

    // MARK: - Subviews

    private var stackedAvatars: some View {
        HStack(spacing: -11) {
            ForEach(Array(config.selectedFriends.prefix(5))) { friend in
                AvatarView(name: friend.displayTitle, imageURL: friend.profileImage, size: 36)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
    }

    @ViewBuilder
    private func dayHeader(for date: Date) -> some View {
        let (primary, secondary) = dayLabelParts(date)
        HStack(spacing: 6) {
            Text(primary)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            if let secondary {
                Text(secondary)
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func slotCard(_ slot: TimeSlot) -> some View {
        let isSelected = selectedSlot?.id == slot.id
        Button { selectedSlot = slot } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeRange(from: slot.start, to: slot.end))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                if slot.isEveryoneFree {
                    Label("Everyone is free", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                } else {
                    let avail = slot.availableFriends.count
                    let total = config.selectedFriends.count
                    Label("\(avail)/\(total) friends available", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color(red: 0.85, green: 0.6, blue: 0.0))
                    Text("Missing: \(slot.busyFriends.map(\.displayTitle).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dayLabelParts(_ date: Date) -> (String, String?) {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let dateStr = fmt.string(from: date)
        if cal.isDateInToday(date)    { return ("Today", dateStr) }
        if cal.isDateInTomorrow(date) { return ("Tomorrow", dateStr) }
        return (dateStr, nil)
    }

    private func timeRange(from start: Date, to end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func sendInvites() {
        guard let slot = selectedSlot,
              let userId = supabase.session?.user.id else { return }
        service.createSession(
            createdBy: userId,
            spotId: nil,
            starts: slot.start,
            ends: slot.end,
            invitedUsers: config.selectedFriends.map(\.userId)
        )
        sessionSent = true
    }
}

#Preview {
    let config = SessionConfig(
        selectedFriends: [],
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
        duration: 2,
        earliestStart: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
        latestEnd: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    )
    NavigationStack {
        FindAvailabilityView(config: config, path: .constant(NavigationPath()))
            .environment(\.supabaseManager, SupabaseManager.shared)
    }
}