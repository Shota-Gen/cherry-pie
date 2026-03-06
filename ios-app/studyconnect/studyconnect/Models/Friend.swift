//
//  Friend.swift
//  studyconnect
//
//  Created by Copilot on 3/6/26.
//

import Foundation

struct Friend: Identifiable {
    let id: UUID
    let icon: String // SF Symbol name
    let name: String
    let location: String
    let distance: Double // in miles
    
    init(id: UUID = UUID(), icon: String, name: String, location: String, distance: Double) {
        self.id = id
        self.icon = icon
        self.name = name
        self.location = location
        self.distance = distance
    }
}
