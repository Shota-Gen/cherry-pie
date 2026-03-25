//
//  LoginView.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//

import SwiftUI
import Auth

struct LoginView: View {
    @Environment(\.supabaseManager) var supabase

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 8) {
                Text("StudyConnect")
                    .font(.system(size: 34, weight: .bold))
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if let user = supabase.session?.user {
                VStack(spacing: 8) {
                    Text("Logged in as")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(user.email ?? "Unknown")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Device ID linked")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            } else {
                Button {
                    Task {
                        await supabase.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect to Google account")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            Text("Required to use StudyConnect")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("By continuing, you agree to sign in with your Google account.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .background {
            LinearGradient(
                colors: [Color.white, Color(red: 0.94, green: 0.96, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
