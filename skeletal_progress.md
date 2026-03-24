# StudyConnect — Skeletal Product Gap Analysis

> Analysis of the entire codebase against the 9 required feature areas. Each feature is rated and broken down by what exists, what's missing, and where it lives in the code.

---

## Summary Matrix

| # | Feature | Status | Backend | iOS | DB |
|---|---------|--------|---------|-----|----|
| 1 | User Data Initialization | 🟢 Done | ✅ | ✅ | ✅ |
| 2 | User Device Association | 🟢 Done | ✅ | ✅ | ✅ |
| 3 | Initialize Location Services | 🟡 Partial | ⚠️ | ✅ | ✅ |
| 4 | Designated Study Spots | 🟡 Partial | ✅ | ⚠️ | ✅ |
| 5 | Location Sharing in the Zone | 🔴 Not Started | ❌ | ❌ | ❌ |
| 6 | Google Integration | 🟡 Partial | ❌ | ✅ | ✅ |
| 7 | Private Sessions | 🟡 Partial | ✅ | ⚠️ | ✅ |
| 8 | Switch to UWB Tracking | 🔴 Not Started | ❌ | ❌ | ❌ |
| 9 | AR Camera View | 🟡 Partial | N/A | ⚠️ | N/A |

---

## 1. User Data Initialization — 🟢 Done

**What exists:**
- DB schema: `public.users` table with all needed fields ([init_core_identity.sql](file:///Users/sgen/dev/school/eecs498/studyconnect/supabase/migrations/20260223062651_init_core_identity.sql))
- Backend: `POST /users/` creates Supabase Auth user + inserts profile row ([users.py](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/users.py))
- iOS: `UserProfile` model mirrors DB schema ([UserProfile.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Models/UserProfile.swift))
- Seed data for test user exists ([seed.sql](file:///Users/sgen/dev/school/eecs498/studyconnect/supabase/seed.sql))

**What's missing:** Nothing for skeletal. ✅ Complete.

---

## 2. User Device Association — 🟢 Done

**What exists:**
- DB: `device_id TEXT UNIQUE` column on `public.users`
- iOS: `SupabaseManager.linkDeviceToUser()` writes `UIDevice.current.identifierForVendor` to DB on login ([SupabaseManager.swift:72-90](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/SupabaseManager.swift#L72-L90))
- Backend: [UserCreate](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/users.py#20-25) model accepts optional `device_id`

**What's missing:** Nothing for skeletal. ✅ Complete.

---

## 3. Initialize Location Services — 🟡 Partial

**What exists:**
- iOS: [LocationManager.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Services/LocationManager.swift) initializes `CLLocationManager`, requests `whenInUseAuthorization`, starts updating location ([LocationManager.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Services/LocationManager.swift))
- iOS: Location updates are pushed to Supabase (`last_known_lat`, `last_known_lng`) via `SupabaseManager.updateLocation()`
- DB: Columns for `last_known_lat`, `last_known_lng` exist

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| [Info.plist](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Info.plist) location usage descriptions | `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` keys are **not present** in [Info.plist](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Info.plist) — the app will crash on first location prompt | iOS |
| Always authorization | Only `whenInUse` is requested; region monitoring (Feature #5) needs `requestAlwaysAuthorization()` | iOS |
| `LocationManager` not wired into app | No view appears to instantiate or hold a `@StateObject` / `@State` reference to the `LocationManager` — confirm it's being used in the view hierarchy | iOS |

---

## 4. Designated Study Spots — 🟡 Partial

**What exists:**
- DB: `public.study_spots` table with PostGIS `geofence` polygons, spatial index ([init_core_identity.sql](file:///Users/sgen/dev/school/eecs498/studyconnect/supabase/migrations/20260223062651_init_core_identity.sql))
- DB: 2 seed zones — UGLI and Fishbowl with real polygon coordinates
- Backend: `GET /studyspots/public/` fetches all spots from DB ([studyspots.py](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/studyspots.py))
- iOS: [StudySpot](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/studyspots.py#19-29) model exists, `SessionService.getStudySpots()` returns hardcoded list (stub)

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| iOS → Backend hookup | `SessionService.getStudySpots()` returns hardcoded data instead of calling `/studyspots/public/` | iOS |
| Display hardcoded zones in UI | No map view showing study zone boundaries; [MapView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/Tabs/MapView.swift) exists but needs study spot overlay | iOS |
| Store zone coordinates client-side | Need to cache study spot center coordinates for geofence registration | iOS |
| CoreLocation region monitoring | `CLLocationManager.startMonitoring(for: CLCircularRegion)` not implemented anywhere — needed for geofence enter/exit detection | iOS |
| Add more study spots | Only 2 spots seeded (UGLI, Fishbowl); spec mentions Hatcher. Backend has hardcoded list with 5 spots but DB only has 2 | DB |

---

## 5. Location Sharing in the Zone — 🔴 Not Started

**What exists:**
- Location updates go to Supabase (`last_known_lat/lng`), but **not conditionally** on being in a zone

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| Geofence enter/exit callbacks | Implement `CLLocationManagerDelegate` methods `didEnterRegion` / `didExitRegion` | iOS |
| Broadcast trigger on zone entry | When entering a zone: start frequent location updates and broadcast to all app users | iOS + Backend |
| Stop broadcasting on zone exit | When exiting: stop broadcasting, optionally clear last-known location | iOS + Backend |
| Real-time broadcast infrastructure | No WebSocket, Supabase Realtime subscription, or push mechanism for "user X is now in zone Y" | Backend |
| Backend endpoint for zone status | No API to get "who is currently in this zone" or "broadcast my zone presence" | Backend |
| DB: Active zone presence table | No table tracking which users are currently in which zones | DB |

---

## 6. Google Integration — 🟡 Partial

**What exists:**
- iOS: Full Google Sign-In flow with nonce → GIDSignIn → Supabase Auth via `signInWithIdToken` ([SupabaseManager.swift:36-69](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/SupabaseManager.swift#L36-L69))
- iOS: [Info.plist](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Info.plist) has `GIDClientID` and URL scheme configured
- DB: `public.external_auth_tokens` table with encrypted access/refresh token columns
- Backend: `google-api-python-client` and `google-auth-oauthlib` in [requirements.txt](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/requirements.txt)

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| OAuth code exchange endpoint | No backend endpoint to exchange authorization code for access/refresh tokens | Backend |
| Token encryption & storage | `external_auth_tokens` table exists but no backend code writes to it | Backend |
| Google Calendar API integration | No endpoint to read/write calendar data; `SessionService.getSuggestedSlots()` is all stub | Backend |
| Token refresh logic | No code to refresh expired Google tokens using stored refresh token | Backend |
| iOS: Send auth code to backend | iOS signs in directly with Supabase Auth but doesn't send Google's access token to backend for Calendar API use | iOS |

---

## 7. Private Sessions — 🟡 Partial

**What exists:**
- DB: [sessions](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/sessions.py#372-442) + `session_members` tables, `session_type` enum, private session migration
- Backend: Full CRUD — create private session, get session, list user sessions, respond to invite ([sessions.py](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/routers/sessions.py))
- Backend: Email invites (stubbed via [services/email.py](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/services/email.py))
- iOS: Views exist — `SessionDetailsView`, `FindAvailabilityView`, `SelectFriendsView`, `SessionInviteRowView`, `SessionAcceptedModal`
- iOS: `SessionService.createSession()` exists (stub), `SessionInviteService` has accept/decline stubs

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| iOS → Backend session creation | `SessionService.createSession()` is a stub print statement; needs to call `POST /sessions/private` | iOS |
| iOS → Backend invite response | `SessionInviteService.acceptInvite/declineInvite` are stubs; need to call `PATCH /sessions/{id}/respond` | iOS |
| iOS → Backend session list | No call to `GET /sessions/user/{user_id}` to show user's sessions | iOS |
| Email invite delivery | [services/email.py](file:///Users/sgen/dev/school/eecs498/studyconnect/backend-api/services/email.py) is fully stubbed — needs a real email provider (SendGrid, Resend, etc.) | Backend |
| Session invites by email | Spec says "Input emails to invite users" but backend uses `invitee_ids` (UUIDs). Need email-to-user lookup or email-based invite flow | Backend |

---

## 8. Switch to UWB Tracking — 🔴 Not Started

**What exists:**
- Backend relay Dockerfile exists (Swift-based UDP relay) but **no source code** (`Package.swift`, `Sources/` are missing)
- Docker-compose has relay service commented out

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| GPS proximity detection | Backend/iOS logic to detect when two users are within 10m using GPS coordinates | Backend + iOS |
| NearbyInteraction framework | iOS `NISession` setup for UWB peer-to-peer distance/direction measurement | iOS |
| Discovery token exchange | Mechanism to exchange `NIDiscoveryToken` between two devices — needs the relay service | Relay |
| Relay service source code | No `Package.swift`, no `Sources/` directory in `backend-relay/` — the entire UDP relay is unbuilt | Relay |
| UWB output model | `{distanceMeters, directionVector}` data model and publishing mechanism | iOS |
| MultipeerConnectivity or WebSocket | Need a transport layer for exchanging discovery tokens between devices | iOS + Relay |

---

## 9. AR Camera View — 🟡 Partial

**What exists:**
- iOS: [ARNavigationView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/AR/ARNavigationView.swift) — full AR view with RealityKit `ARView`, world tracking, billboard rendering of friend profile ([ARNavigationView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/AR/ARNavigationView.swift))
- iOS: [ARNavigationSelectFriendView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/AR/ARNavigationSelectFriendView.swift) — friend selection UI for AR navigation
- iOS: [ARCameraPermissionService.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Services/ARCameraPermissionService.swift) — camera permission tracking (stubbed backend)
- iOS: [ARCameraView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/AR/ARCameraView.swift) — **empty placeholder** (just shows text "ARCameraView")

**What's missing:**

| Gap | Details | Owner |
|-----|---------|-------|
| UWB-driven positioning | AR billboard is hardcoded at `[0, 0, -1.2]` (1.2m in front of camera). Needs real UWB `{distance, direction}` data to position the 3D object | iOS |
| Dynamic object movement | Object position needs to update in real-time as UWB data streams in | iOS |
| Distance display is hardcoded | Top bar shows "12m" as a static string — needs live UWB distance | iOS |
| 3D object rendering | Spec asks for "floating sphere"; current impl uses a flat billboard plane. Could upgrade to 3D sphere with glow effect | iOS |
| [ARCameraView.swift](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Views/AR/ARCameraView.swift) empty | Appears to be an unused placeholder — determine if it should replace/wrap `ARNavigationView` | iOS |

---

## Priority Order for Remaining Work

### 🔴 Critical Path (Features 5 & 8 — not started, dependencies for other features)

1. **Feature 5: Location Sharing** — Geofence region monitoring, zone presence broadcasting, real-time infrastructure
2. **Feature 8: UWB Tracking** — Relay service source code, NearbyInteraction framework, discovery token exchange

### 🟡 Integration Work (connecting existing pieces)

3. **Feature 4: Study Spots** — Wire iOS to backend, add CoreLocation region monitoring, add more seed data
4. **Feature 7: Private Sessions** — Wire iOS stubs to backend endpoints, implement email delivery
5. **Feature 6: Google Integration** — Backend OAuth token exchange, Calendar API, token storage
6. **Feature 3: Location Services** — Add [Info.plist](file:///Users/sgen/dev/school/eecs498/studyconnect/ios-app/studyconnect/studyconnect/Info.plist) keys, upgrade to `Always` authorization, confirm `LocationManager` is in use
7. **Feature 9: AR Camera** — Integrate UWB data into AR positioning (blocked by Feature 8)

### ✅ Complete

8. **Feature 1: User Data** — Done
9. **Feature 2: Device Association** — Done
