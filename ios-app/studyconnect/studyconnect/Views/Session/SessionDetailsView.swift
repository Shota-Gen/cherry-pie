//
//  SessionDetailsView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

/// Step 2 of session scheduling: configure date range, duration, and time window.
/// Includes a custom date-range picker sheet with calendar grid and range highlighting.
/// "Find Availability" button pushes FindAvailabilityView via FriendsRoute.
struct SessionDetailsView: View {
    var selectedFriends: [UserProfile]     // friends chosen in Step 1 (SelectFriendsView)

    // ── Session parameters (all @State — owned by this view) ──
    @State private var startDate = Date()   // beginning of the date range to search for slots
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()  // default: 1 week window
    @State private var duration = 2         // session length in hours (1–8)
    @State private var earliestStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()  // "no earlier than" time
    @State private var latestEnd = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()     // "no later than" time
    @State private var showDatePicker = false  // controls the DateRangePickerSheet presentation

    // Formats the selected date range as "Mon, Jan 1 – Sun, Jan 7" or just one day
    private var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return fmt.string(from: startDate)
        }
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    /// Earliest valid latestEnd = earliestStart + duration hours.
    /// This prevents the user from setting an end time that makes
    /// the window shorter than the requested session length.
    private var minLatestEnd: Date {
        Calendar.current.date(byAdding: .hour, value: duration, to: earliestStart) ?? earliestStart
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── DATE RANGE section ──
                    // Tapping the row opens a custom calendar sheet (DateRangePickerSheet)
                    // where the user picks start and end dates for availability search.
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

                    // ── SESSION DURATION picker ──
                    // Menu-style picker for 1–8 hours.
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
                            .pickerStyle(.menu)  // compact dropdown on iOS
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    // ── TIME PREFERENCES section ──
                    // Two time pickers: earliest start (morning) and latest end (evening).
                    // The latest-end picker is clamped so it can't be earlier than
                    // earliestStart + duration (see minLatestEnd computed property).
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("TIME PREFERENCES")

                        VStack(spacing: 0) {
                            // Earliest start time row
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

                            Divider().padding(.leading, 56)  // indent to align with text

                            // Latest end time row — minimum is clamped to earliestStart + duration
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

                    Color.clear.frame(height: 80)  // bottom padding for scroll content
                }
                .padding()
            }

            // ── "Find Availability" button pinned at bottom ──
            // Bundles all session parameters into a SessionConfig struct
            // and pushes FindAvailabilityView via FriendsRoute.
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
        // Present the custom calendar date-range picker as a sheet
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerSheet(startDate: $startDate, endDate: $endDate)
        }
        // Auto-clamp latestEnd when earliestStart or duration changes
        .onChange(of: earliestStart) { clampLatestEnd() }
        .onChange(of: duration) { clampLatestEnd() }
    }

    /// If latestEnd drifted below the minimum allowed value, snap it up.
    private func clampLatestEnd() {
        if latestEnd < minLatestEnd { latestEnd = minLatestEnd }
    }

    /// Small all-caps section header used throughout the form.
    @ViewBuilder private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.gray)
    }
}

// MARK: - Date Range Picker Sheet
/// Custom calendar sheet for selecting a start–end date range.
/// Uses a two-tap flow: first tap sets start, second tap sets end.
/// Displays a visual range highlight (pill corridor) between start and end.
private struct DateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var localStart: Date
    @State private var localEnd: Date
    @State private var isSelectingEnd = false
    @State private var displayMonth: Date

    private let cal = Calendar.current
    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)  // 7-column calendar grid
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // Initialize local copies of the dates so edits only commit on "Done"
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
            // ── Header: dynamic prompt + Done button ──
            HStack {
                // Changes to "Select end date" after the first tap
                Text(isSelectingEnd ? "Select end date" : "Select start date")
                    .font(.headline)
                Spacer()
                // Commits localStart/localEnd back to the parent bindings and dismisses
                Button("Done") {
                    startDate = localStart
                    endDate = localEnd
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            .padding()

            // ── Month navigation chevrons ──
            // Left chevron disabled when already on the current month (can't go to past)
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

            // ── Sun–Sat weekday header row ──
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

            // ── Calendar day grid ──
            // gridDays() returns [Date?] where nil = empty cell before day 1.
            // Each non-nil cell is a RangeDayCell that handles tap + range highlighting.
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
        // .presentationDetents allows the sheet to sit at medium or expand to large
        .presentationDetents([.medium, .large])
    }

    /// Formatted month label for the navigation header (e.g. "March 2026")
    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayMonth)
    }

    /// True when displayMonth is the current calendar month (disables back chevron)
    private var isOnCurrentMonth: Bool {
        cal.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Two-tap date selection logic:
    /// 1st tap → sets start date, enters "selecting end" mode
    /// 2nd tap → if before start, restarts; otherwise sets end date
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

    /// Shifts the displayed month forward or backward by `delta` months
    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: displayMonth) {
            displayMonth = m
        }
    }

    /// Builds the array of optional dates for the current month's grid.
    /// Leading nil entries represent empty cells before the 1st falls on its weekday.
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
/// Individual day cell in the calendar grid. Handles:
/// - Blue filled circle for start/end dates
/// - Light blue corridor background for days in the selected range
/// - Gray text for past dates (non-tappable)
/// - Half-corridor on start (right half) and end (left half) for the pill effect
private struct RangeDayCell: View {
    let date: Date
    let start: Date
    let end: Date
    let today: Date
    let onTap: () -> Void

    private let cal = Calendar.current
    private var dayNum: Int { cal.component(.day, from: date) }  // day-of-month number
    private var isPast: Bool { cal.startOfDay(for: date) < today }  // true for dates before today
    private var isStart: Bool { cal.isDate(date, inSameDayAs: start) }  // is this the range start?
    private var isEnd: Bool { cal.isDate(date, inSameDayAs: end) }      // is this the range end?
    private var isSingle: Bool { cal.isDate(start, inSameDayAs: end) }  // start == end (single day)
    // True for days strictly between start and end (not including endpoints)
    private var isInRange: Bool {
        guard !isSingle else { return false }
        let d = cal.startOfDay(for: date)
        return d > start && d < end
    }

    var body: some View {
        Text("\(dayNum)")
            // Bold for range endpoints, regular for other days
            .font(.system(size: 16, weight: (isStart || isEnd) ? .semibold : .regular))
            // Gray for past, white for endpoints (they sit on blue circle), default otherwise
            .foregroundColor(
                isPast ? Color(.systemGray4)
                : (isStart || isEnd) ? .white
                : .primary
            )
            .frame(width: 36, height: 36)
            // Blue filled circle behind start/end day numbers
            .background((isStart || isEnd) && !isPast ? Color.blue : Color.clear)
            .clipShape(Circle())
            .background {
                // Range corridor background creates the "pill" effect between start and end.
                // For in-range days: full-width light blue.
                // For start day: only the right half is colored (connects to the range).
                // For end day: only the left half is colored.
                if isInRange {
                    Color.blue.opacity(0.12)
                        .frame(maxWidth: .infinity, maxHeight: 36)
                } else if isStart && !isSingle {
                    // Right half colored: clear | blue corridor
                    HStack(spacing: 0) {
                        Color.clear.frame(maxWidth: .infinity)
                        Color.blue.opacity(0.12).frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 36)
                } else if isEnd && !isSingle {
                    // Left half colored: blue corridor | clear
                    HStack(spacing: 0) {
                        Color.blue.opacity(0.12).frame(maxWidth: .infinity)
                        Color.clear.frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 36)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .contentShape(Rectangle())  // expand tap target to full cell
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    NavigationStack {
        SessionDetailsView(selectedFriends: [])
    }
}
