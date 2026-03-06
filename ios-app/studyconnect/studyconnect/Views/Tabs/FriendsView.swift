//
//  FriendsView.swift
//  studyconnect
//
//  Created by Copilot on 3/6/26.
//

import SwiftUI

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink("Add Friend", destination: AddFriendView())
                NavigationLink("Create Session", destination: SelectFriendsView())
            }
            .navigationTitle("Friends")
        }
    }
}

#Preview {
    FriendsView()
}
