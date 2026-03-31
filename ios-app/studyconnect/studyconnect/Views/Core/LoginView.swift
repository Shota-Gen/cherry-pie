//
//  LoginView.swift
//  studyconnect
//
//  Created by Shota Gen on 2/23/26.
//

import SwiftUI
import Auth

/// Sign-in screen shown when no Supabase session exists.
/// Presents a single "Connect to Google account" button that triggers
/// the full Google OAuth flow via SupabaseManager.
struct LoginView: View {
    // SupabaseManager is read via @Environment — it holds the current auth session
    @Environment(\.supabaseManager) var supabase

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // App branding — title + subtitle centered at the top of visible area
            VStack(spacing: 8) {
                Text("StudyConnect")
                    .font(.system(size: 34, weight: .bold))
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Conditional branch: if a session already exists (edge case where
            // the view is still on screen during a re-render), show the
            // authenticated user’s email as confirmation.
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
                // Primary CTA — triggers the Google OAuth flow.
                // Task{} launches a structured async call; SupabaseManager handles
                // the full OAuth redirect, token exchange, and session storage.
                Button {
                    Task {
                        await supabase.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 14) {
                        // Google icon placeholder (SF Symbol since we can’t bundle
                        // the official Google logo without licensing issues)
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

                        // Chevron indicates tappable row — standard iOS affordance
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
                .buttonStyle(.plain)   // removes default blue tint so we control colors
            }

            Spacer()

            // Legal disclaimer pinned near the bottom
            Text("By continuing, you agree to sign in with your Google account.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        // Full-screen gradient background: white → light blue, behind safe area
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
