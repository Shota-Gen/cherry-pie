# StudyConnect Backend Hookups

Only the backend hookup points are listed below.

## Friends

File: `ios-app/studyconnect/studyconnect/Services/FriendsService.swift`

1. `getFriendsList() -> [Friend]`
- Hook this to: backend endpoint for signed-in user's friends list.

2. `addFriend(email: String)`
- Hook this to: backend endpoint to send friend request by email.
- Triggered from: `ios-app/studyconnect/studyconnect/Views/Friends/AddFriendView.swift`.

3. `deleteFriend(id: UUID)`
- Hook this to: backend endpoint to remove/unfriend.

## Profile

File: `ios-app/studyconnect/studyconnect/Services/ProfileService.swift`

1. `updateProfile(_ profile: UserProfile)`
- Hook this to: backend endpoint to save profile edits.
- Triggered from: `ios-app/studyconnect/studyconnect/Views/Profile/EditProfileView.swift`.

2. `fetchProfileFromAPIStub() -> UserProfile?`
- Hook this to: backend endpoint to fetch the signed-in user's profile.
- Replace the stub response mapping in this function with real API data.
