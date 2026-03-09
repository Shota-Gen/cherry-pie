//
//  AddFriendView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct AddFriendView: View {
    @State private var email: String = ""
    @State private var statusMessage: String = ""
    @State private var statusColor: Color = .gray
    @State private var service = FriendsService()

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        Form {
            Section("Friend Email") {
                TextField("friend@school.edu", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Text("Email is required to add a friend")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Button("Add Friend") {
                    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        statusMessage = "Please enter a friend email."
                        statusColor = .red
                        return
                    }
                    guard isEmailValid else {
                        statusMessage = "Please enter a valid email address."
                        statusColor = .red
                        return
                    }

                    service.addFriend(email: trimmed)
                    statusMessage = "Friend request stub sent to \(trimmed)."
                    statusColor = .green
                    email = ""
                }
                .disabled(!isEmailValid)
            }

            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(statusColor)
                }
            }
        }
        .navigationTitle("Add Friend")
    }
}

#Preview {
    AddFriendView()
}
