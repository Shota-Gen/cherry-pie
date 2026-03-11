# StudyConnect Backend Hookups

Only the backend hookup points are listed below.

## Friends

File: `ios-app/studyconnect/studyconnect/Services/FriendsService.swift`

1. `getFriendsList() -> [UserProfile]`
   - Hook to: backend endpoint for signed-in user's friends list.
   - SQL: `SELECT * FROM public.users WHERE user_id IN (SELECT friend_id FROM public.friends WHERE user_id = <current_user>)`

2. `addFriend(email: String)`
   - Hook to: backend endpoint to send friend request by email.
   - Triggered from: `Views/Friends/AddFriendView.swift`.

3. `deleteFriend(id: UUID)`
   - Hook to: backend endpoint to remove/unfriend.

4. `getSuggestedFriends() -> [UserProfile]`
   - Hook to: real suggestion algorithm (e.g. nearby users, frequent study partners).
   - Currently delegates to `getFriendsList()`.
   - Used by: `Views/Session/SelectFriendsView.swift`.

## Profile

File: `ios-app/studyconnect/studyconnect/Services/ProfileService.swift`

1. `updateProfile(_ profile: UserProfile)`
   - Hook to: backend endpoint / Supabase upsert to save profile edits.
   - Triggered from: `Views/Profile/EditProfileView.swift`.

2. `fetchProfileFromAPIStub() -> UserProfile?`
   - Hook to: backend endpoint to fetch the signed-in user's profile.
   - Replace the stub response mapping with real API data.

## Sessions

File: `ios-app/studyconnect/studyconnect/Services/SessionService.swift`

1. `getStudySpots() -> [StudySpot]`
   - Hook to: `SELECT spot_id, name FROM public.study_spots WHERE is_active = TRUE`
   - Used by: `FindAvailabilityView` (currently removed from UI; keep for future spot selection).

2. `getSuggestedSlots(config: SessionConfig) -> [TimeSlot]`
   - Hook to: Google Calendar API availability check + LLM time prediction.
   - Input: `SessionConfig` (friends, date range, duration, earliest start, latest end).
   - Returns: array of `TimeSlot` with `availableFriends` and `busyFriends` per slot.
   - Currently: returns 1–3 randomly chosen 30-min-granularity slots per day, with 0–2 friends randomly marked busy (always ≥1 available).
   - Used by: `Views/Session/FindAvailabilityView.swift`.

3. `createSession(createdBy:spotId:starts:ends:invitedUsers:)`
   - Hook to:
     1. `INSERT INTO public.sessions (created_by, study_spot_id, starts_at, ends_at)`
     2. `INSERT INTO public.session_members (session_id, user_id, status)` — owner row `'accepted'`, invitee rows `'pending'`
   - `spotId` is now optional (`UUID?`); pass `nil` until spot selection is re-introduced.
   - Triggered from: `Views/Session/FindAvailabilityView.swift` Send Invites button.
