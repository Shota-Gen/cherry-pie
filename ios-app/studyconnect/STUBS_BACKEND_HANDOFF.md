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

1. `fetchProfile(email: String?) -> UserProfile`
   - Hook to: backend endpoint / Supabase query to fetch user profile by email.
   - SQL: `SELECT * FROM public.users WHERE email = ?`
   - Triggered from: `Views/Tabs/ProfileView.swift` (onAppear) and `Views/Profile/EditProfileView.swift` (onAppear).
   - Returns: full `UserProfile` object with displayName, major, universityYear, profileImage, isInvisible, etc.

2. `fetchProfileByID(userID: String) -> UserProfile`
   - Hook to: backend endpoint / Supabase query to fetch user profile by user ID.
   - SQL: `SELECT * FROM public.users WHERE user_id = ?`
   - Alternative fetch method; currently unused but available for direct UUID lookups.
   - Returns: full `UserProfile` object.

3. `updateProfile(_ profile: UserProfile)`
   - Hook to: backend endpoint / Supabase update to save profile edits.
   - SQL: `PATCH /profiles/{user_id}` with fields: displayName, major, universityYear, profileImage.
   - Triggered from: `Views/Profile/EditProfileView.swift` Save Changes button.

4. `updateGhostMode(enabled: Bool, userID: String)`
   - Hook to: backend endpoint to toggle invisibility / location visibility.
   - SQL: `PATCH /profiles/{user_id}` with field: `{ isInvisible: enabled }`
   - Triggered from: `Views/Tabs/ProfileView.swift` Ghost Mode toggle (purple).
   - Real-time: toggle should immediately update backend when changed.

5. `updatePushNotifications(enabled: Bool, userID: String)`
   - Hook to: backend endpoint to toggle push notification preference.
   - SQL: `PATCH /profiles/{user_id}` with field: `{ pushNotificationsEnabled: enabled }`
   - Triggered from: `Views/Tabs/ProfileView.swift` Push Notifications toggle (yellow).
   - Real-time: toggle should immediately update backend when changed.

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

## Session Invites (accept-card details)

File: `ios-app/studyconnect/studyconnect/Services/SessionInviteService.swift`

1. `fetchSessionExtrasStub(sessionId:studySpotName:) -> SessionExtras`
   - **STUB.** Returns `locationName`, `locationAddress`, and `meetingLink` for a session so the
     invite and accepted-session cards can render a map pin and a Google Meet link.
   - Currently returns deterministic example data keyed off the session UUID (3 rotating
     samples: Shapiro UGLI, Hatcher, Duderstadt with hard-coded U-M addresses and fake
     Meet URLs). `studySpotName` is used when available so the example matches the
     real spot name.
   - Hook to:
     1. `SELECT name, address FROM public.study_spots WHERE spot_id = ?` for the physical location
        (requires adding an `address TEXT` column to `study_spots`, or a new `location_address`
        column on `sessions` if the address should be a free-form override).
     2. The Google Calendar event created in `services/google_calendar_invite.py` exposes a
        `hangoutLink` field — persist it on `sessions.meeting_link` when creating the session, then
        return it here so the iOS UI can show a "Join Google Meet" button.
   - Used by: `getPendingInvites()`, rendered on `Views/Components/SessionInviteRowView.swift`
     and `Views/Components/SessionAcceptedModal.swift`.

2. Real fields already wired from Supabase in `getPendingInvites()` (no backend work needed):
   - `sessions.title` → `SessionInvite.title`
   - `sessions.description` → `SessionInvite.description`
   - `sessions.study_spot_id` → joined with `study_spots.name` → fed into the stub above
     as `studySpotName`.
