//
//  SessionDetailsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct SessionDetailsView: View {
    var selectedFriends: [UserProfile]

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var duration = 2
    @State private var earliestStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var latestEnd = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showDatePicker = false

    private var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return fmt.string(from: startDate)
        }
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    /// Earliest valid value for latestEnd = earliestStart + chosen duration.
    private var minLatestEnd: Date {
        Calendar.current.date(byAdding: .hour, value: duration, to: earliestStart) ?? earliestStart
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // DATE RANGE
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("DATE RANGE")

                        Button { showDatePicker = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                Text(dateRangeLabel)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }

                        Text("Select the days you want to study together")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }

                    // SESSION DURATION
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("SESSION DURATION")

                        HStack {
                            Text("Duration").fontWeight(.medium)
                            Spacer()
                            Picker("Duration", selection: $duration) {
                                ForEach(1...8, id: \.self) { n in
                                    Text("\(n) \(n == 1 ? "Hour" : "Hours")").tag(n)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    // TIME PREFERENCES
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("TIME PREFERENCES")

                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Image(systemName: "sun.max.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Earliest Start").fontWeight(.medium)
                                    Text("Morning Slot").font(.caption).foregroundColor(.gray)
                                }

                                Spacer()

                                DatePicker("", selection: $earliestStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding()

                            Divider().padding(.leading, 56)

                            HStack(spacing: 14) {
                                Image(systemName: "moon.fill")
                                    .font(.title2)
                                    .foregroundColor(.indigo)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Latest End").fontWeight(.medium)
                                    Text("Evening Slot").font(.caption).foregroundColor(.gray)
                                }

                                Spacer()

                                DatePicker("", selection: $latestEnd, in: minLatestEnd..., displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding()
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    Color.clear.frame(height: 80)
                }
                .padding()
            }

            NavigationLink(value: FriendsRoute.findAvailability(SessionConfig(
                selectedFriends: selectedFriends,
                startDate: startDate,
                endDate: endDate,
                duration: duration,
                earliestStart: earliestStart,
                latestEnd: latestEnd
            ))) {
                HStack(spacing: 8) {
                    Text("Find Availability")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerSheet(startDate: $startDate, endDate: $endDate)
        }
        // Clamp latestEnd whenever the minimum changes
        .onChange(of: earliestStart) { clampLatestEnd() }
        .onChange(of: duration) { clampLatestEnd() }
    }

    private func clampLatestEnd() {
        if latestEnd < minLatestEnd { latestEnd = minLatestEnd }
    }

    @ViewBuilder private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.gray)
    }
}

// MARK: - Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var localStart: Date
    @State private var localEnd: Date
    @State private var isSelectingEnd = false
    @State private var displayMonth: Date

    private let cal = Calendar.current
    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(startDate: Binding<Date>, endDate: Binding<Date>) {
        _startDate = startDate
        _endDate = endDate
        let s = Calendar.current.startOfDay(for: startDate.wrappedValue)
        let e = Calendar.current.startOfDay(for: endDate.wrappedValue)
        _localStart = State(initialValue: s)
        _localEnd = State(initialValue: e)
        let comps = Calendar.current.dateComponents([.year, .month], from: startDate.wrappedValue)
        _displayMonth = State(initialValue: Calendar.current.date(from: comps) ?? startDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title + Done
            HStack {
                Text(isSelectingEnd ? "Select end date" : "Select start date")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    startDate = localStart
                    endDate = localEnd
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            .padding()

            // Month navigation
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isOnCurrentMonth ? Color(.systemGray4) : .blue)
                        .padding(10)
                }
                .disabled(isOnCurrentMonth)
                Spacer()
                Text(monthLabel)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(10)
                }
            }
            .padding(.horizontal, 4)

            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(wd)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.systemGray2))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Day grid
            LazyVGrid(columns: gridCols, spacing: 0) {
                ForEach(Array(gridDays().enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        RangeDayCell(date: day, start: localStart, end: localEnd, today: cal.startOfDay(for: Date())) {
                            handleTap(day)
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 20)
        }
        .presentationDetents([.medium, .large])
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayMonth)
    }

    private var isOnCurrentMonth: Bool {
        cal.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }

    private func handleTap(_ date: Date) {
        let day = cal.startOfDay(for: date)
        guard day >= cal.startOfDay(for: Date()) else { return }
        if !isSelectingEnd {
            // First tap: set start, wait for end
            localStart = day
            localEnd = day
            isSelectingEnd = true
        } else {
            if day < localStart {
                // Tapped before current start: restart
                localStart = day
                localEnd = day
            } else {
                // Valid end date
                localEnd = day
                isSelectingEnd = false
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: displayMonth) {
            displayMonth = m
        }
    }

    private func gridDays() -> [Date?] {
        guard
            let first = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)),
            let count = cal.range(of: .day, in: .month, for: displayMonth)?.count
        else { return [] }
        let offset = (cal.component(.weekday, from: first) - 1 + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<count {
            result.append(cal.date(byAdding: .day, value: i, to: first))
        }
        return result
    }
}

// MARK: - Range Day Cell

private struct RangeDayCell: View {
    let date: Date
    let start: Date
    let end: Date
    let today: Date
    let onTap: () -> Void

    private let cal = Calendar.current
    private var dayNum: Int { cal.component(.day, from: date) }
    private var isPast: Bool { cal.startOfDay(for: date) < today }
    private var isStart: Bool { cal.isDate(date, inSameDayAs: start) }
    private var isEnd: Bool { cal.isDate(date, inSameDayAs: end) }
    private var isSingle: Bool { cal.isDate(start, inSameDayAs: end) }
    private var isInRange: Bool {
        guard !isSingle else { return false }
        let d = cal.startOfDay(for: date)
        return d > start && d < end
    }

    var body: some View {
        Text("\(dayNum)")
            .font(.system(size: 16, weight: (isStart || isEnd) ? .semibold : .regular))
            .foregroundColor(
                isPast ? Color(.systemGray4)
                : (isStart || isEnd) ? .white
                : .primary
            )
            .frame(width: 36, height: 36)
            .background((isStart || isEnd) && !isPast ? Color.blue : Color.clear)
            .clipShape(Circle())
            .background {
                // Range corridor background (pill effect)
                if isInRange {
                    Color.blue.opacity(0.12)
                        .frame(maxWidth: .infinity, maxHeight: 36)
                } else if isStart && !isSingle {
                    HStack(spacing: 0) {
                        Color.clear.frame(maxWidth: .infinity)
                        Color.blue.opacity(0.12).frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 36)
                } else if isEnd && !isSingle {
                    HStack(spacing: 0) {
                        Color.blue.opacity(0.12).frame(maxWidth: .infinity)
                        Color.clear.frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 36)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    NavigationStack {
        SessionDetailsView(selectedFriends: [])
    }
}
