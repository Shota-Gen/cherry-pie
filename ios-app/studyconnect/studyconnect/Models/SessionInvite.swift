//
//  SessionInvite.swift
//  studyconnect
//
//  Created by Copilot on 3/13/26.
//

import Foundation

/// A pending study session invitation.  Built from Supabase `session_members`
/// + `sessions` + `users` tables by SessionInviteService.  Computed properties
/// handle all display formatting for the invite row UI.
struct SessionInvite: Identifiable {
    let id: UUID                  // session UUID (used for accept/decline API calls)
    let fromUser: UserProfile     // who created the session
    let startTime: Date
    let endTime: Date
    let createdAt: Date
    
    /// Formatted time range, e.g. "2:00 PM - 5:00 PM"
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        return "\(start) - \(end)"
    }
    
    /// Human-readable day label: "Today", "Tomorrow", or "MMM d"
    var dayLabel: String {
        let today = Calendar.current.startOfDay(for: Date())
        let inviteDay = Calendar.current.startOfDay(for: startTime)
        
        if inviteDay == today {
            return "Today"
        } else if inviteDay == Calendar.current.date(byAdding: .day, value: 1, to: today) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: startTime)
        }
    }
    
    /// Relative timestamp: "now", "5m ago", "2h ago", "1d ago"
    var createdTimeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
