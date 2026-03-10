//
//  FindAvailabilityView.swift
//  studyconnect
//
//  Created by Jawad using Copilot on 3/6/26.
//

import SwiftUI

struct FindAvailabilityView: View {
    // Catches the selected friends from the previous view
    var selectedFriends: [UUID]
    
    // State to hold the chosen time and location
    @State private var selectedDate = Date()
    @State private var selectedSpot = "UGLI"
    
    // A temporary array of study spots (you can pull this from Supabase later)
    let studySpots = ["UGLI", "Law Library", "Ross Building", "Dude (Duderstadt)", "Hatcher"]
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea()
            
            VStack {
                Form {
                    Section(header: Text("Session Details")) {
                        // A native iOS date/time picker
                        DatePicker("Select Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        
                        // A picker for the study spot
                        Picker("Study Spot", selection: $selectedSpot) {
                            ForEach(studySpots, id: \.self) { spot in
                                Text(spot).tag(spot)
                            }
                        }
                    }
                    
                    Section(header: Text("Invites")) {
                        Text("\(selectedFriends.count) Friends Selected")
                            .foregroundColor(.gray)
                    }
                }
                .scrollContentBackground(.hidden) // Removes default form background so it matches your gray theme
                
                Spacer()
                
                // The "Send Invites" Button
                Button(action: {
                    // Phase 3: We will wire this to Supabase next!
                    print("Attempting to create session at \(selectedSpot) for \(selectedFriends.count) friends.")
                }) {
                    Text("Send Invites")
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
        }
        .navigationTitle("Find Availability")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    FindAvailabilityView(selectedFriends: [UUID(), UUID()])
}
