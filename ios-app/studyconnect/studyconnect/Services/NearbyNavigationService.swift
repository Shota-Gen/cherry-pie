//
//  NearbyNavigationService.swift
//  studyconnect
//
//  Created by Jeffrey898 on 3/23/26.
//

import MultipeerConnectivity
import NearbyInteraction
import RealityKit
import ARKit
import CoreMotion
import CoreLocation
import QuartzCore
import Auth

enum PeerToPeerStatus {
    case Inactive
    case Broadcasting
    case Searching
    case Discovered
    case Navigating
}

struct PeerToPeerMessage: Codable {
    let identifier: String
    let data: Data
}

/// How `target` / `targetDistance` were resolved (for debugging).
enum NavigationSourceMode: String, Sendable {
    case uwbDirect
    /// UWB distance is flowing but multilateration has not produced an estimate yet (needs several geometry‑diverse samples).
    case uwbCalibrating
    case uwbMultilateration
    case gps
    case unavailable

    var debugLabel: String {
        switch self {
        case .uwbDirect: return "Pure UWB"
        case .uwbCalibrating: return "UWB (calibrating)"
        case .uwbMultilateration: return "Multilateration"
        case .gps: return "GPS"
        case .unavailable: return "Unavailable"
        }
    }
}

/// Peer navigation: Multipeer + Nearby Interaction + ARKit. **AR UI code** should call `updateBestTargetEstimate(cameraTransform:)` once per frame, then read `target` and `targetDistance` for the peer’s best estimated position and range (UWB → multilateration → GPS).
@Observable
class NearbyNavigationService: NSObject {
    let MINIMUM_MEASUREMENT_DISTANCE: Float = 0.3
    let DATAPOINT_ANGLE_THRESHOLD: Float = 0.15
    private(set) var status: PeerToPeerStatus = PeerToPeerStatus.Inactive
    
    private var currentUser: UserProfile
    public var targetUser: UserProfile? = nil
    private var foundUsers: [MCPeerID: UserProfile] = [:]
    var discoveredUsers: [UserProfile] {
        get {
            return Array(foundUsers.values)
        }
    }
    
    var arview: ARView = ARView(frame: .zero)
    
    private var altimeterStreamingTimer: Timer? = nil
    private var altimeter: CMAltimeter = CMAltimeter()
    private(set) var altitude: Double = 0.0
    
    private(set) var hasData: DarwinBoolean = false
    private var positionCollected: [SIMD3<Float>] = []
    private var distanceCollected: [Float] = []
    /// Internal multilateration-only estimate (UWB distance, no direction). Not the public API — use `target`.
    private var multilaterationSum: SIMD3<Float> = .zero
    private var multilaterationCount: Float = 0.0
    private var multilaterationEstimate: SIMD3<Float> {
        multilaterationCount > 0 ? multilaterationSum / multilaterationCount : .zero
    }

    /// Best estimate of the peer’s position in AR world space (meters). Requires `updateBestTargetEstimate(cameraTransform:)` each frame from the AR view.
    private(set) var target: SIMD3<Float> = .zero
    /// Best estimate of distance to the peer (meters), same priority as `target`. Requires `updateBestTargetEstimate(cameraTransform:)` each frame from the AR view.
    private(set) var targetDistance: Float = 0.0
    /// Which source produced the current `target` (updated in `updateBestTargetEstimate`).
    private(set) var navigationSourceMode: NavigationSourceMode = .unavailable
    
    // UWB direction (when available) can provide a direct target.
    private(set) var uwbDirection: SIMD3<Float>? = nil
    private(set) var uwbHasDirection: Bool = false
    private var directTargetWorld: SIMD3<Float>? = nil
    /// Last UWB range from `NINearbyObject.distance` (meters), if any.
    private var niDistanceMeters: Float? = nil
    private(set) var gps: CLLocationCoordinate2D? = nil
    private var targetGPS: CLLocationCoordinate2D? {
        guard let lat = targetUser?.lastKnownLat, let lng = targetUser?.lastKnownLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    private var targetAltitude: Double { targetUser?.altitude ?? 0 }
    /// Friend position in AR when using GPS — anchored when GPS updates, not re-derived as `camera + offset` every frame (that made distance constant and confused the UI).
    private var gpsFixedWorldTarget: SIMD3<Float>? = nil
    private var lastGpsAnchorCoordinate: CLLocationCoordinate2D? = nil
    /// Rebuild GPS anchor when the user moves this far (meters) so the pin tracks fresh fixes without jumping every frame.
    private let gpsResnapAfterMetersMoved: CLLocationDistance = 5.0
    /// Nearby Interaction can deliver dozens of updates per second when phones are close; processing each one on the main thread starves ARKit.
    private var lastNIProcessMediaTime: CFTimeInterval = 0
    private let niUpdateMinInterval: CFTimeInterval = 1.0 / 24.0
    
    // peer to peer variables
    public var myPeerId: MCPeerID
    
    private var mcSession: MCSession!
    private var mcAdvertiser: MCNearbyServiceAdvertiser!
    private var mcBrowser: MCNearbyServiceBrowser!
    
    // nearby interaction variables
    private var niSession: NISession!
    private var niDiscoveryToken: NIDiscoveryToken!
    
    init(user: UserProfile, locationManager: LocationManager?) {
        currentUser = user
        myPeerId = MCPeerID(displayName: user.userId.uuidString)
        super.init()
        
        // setup multipeer connect
        mcSession = MCSession(
            peer: myPeerId,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        mcSession.delegate = self

        mcAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: nil,
            serviceType: "studyConn"
        )
        mcAdvertiser.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: "studyConn"
        )
        mcBrowser.delegate = self

        // setup nearby interaction
        niSession = NISession()
        niSession.delegate = self
        niDiscoveryToken = niSession.discoveryToken
        
        // begin collecting altitude data
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main, withHandler: { data, error in
                if data != nil {
                    locationManager?.altitude = data!.altitude
                    self.gps = locationManager?.location
                    self.altitude = data!.altitude
                }
            })
        }
    }

    func broadcastUser() {
        if status != PeerToPeerStatus.Inactive {
            deactivate()
        }

        mcAdvertiser.startAdvertisingPeer()
        status = PeerToPeerStatus.Broadcasting
    }
    
    func searchUsers() {
        if status != PeerToPeerStatus.Inactive {
            deactivate()
        }
        
        mcBrowser.startBrowsingForPeers()
        status = PeerToPeerStatus.Searching
    }

    func deactivate() {
        measurementReset()
        switch status {
        case .Inactive:
            return
        case .Broadcasting:
            mcAdvertiser.stopAdvertisingPeer()
            status = PeerToPeerStatus.Inactive
            return
        case .Searching:
            mcBrowser.stopBrowsingForPeers()
            status = PeerToPeerStatus.Inactive
            return
        case .Discovered:
            mcSession.disconnect()
            status = PeerToPeerStatus.Inactive
        case .Navigating:
            niSession.invalidate()
            replaceNISessionAfterInvalidate()
            status = PeerToPeerStatus.Inactive
        }
    }

    /// `NISession` must be recreated after `invalidate()` before exchanging tokens again.
    private func replaceNISessionAfterInvalidate() {
        niSession = NISession()
        niSession.delegate = self
        niDiscoveryToken = niSession.discoveryToken
    }
    
    private func measurementReset() {
        // TODO: double check
        altitude = 0.0
        multilaterationCount = 0.0
        multilaterationSum = .zero
        positionCollected = []
        distanceCollected = []
        hasData = false
        uwbDirection = nil
        uwbHasDirection = false
        directTargetWorld = nil
        niDistanceMeters = nil
        clearGpsFixedWorldAnchor()
        lastNIProcessMediaTime = 0
        target = .zero
        targetDistance = 0.0
        navigationSourceMode = .unavailable
        // Do not call `arview.session.pause()` here. `deactivate()` runs on NI invalidation and
        // Multipeer disconnect; pausing AR on those paths leaves the camera stopped until a new
        // `session.run` (often never if the user stays in the AR UI). Pause only when leaving AR.
    }

    /// Stops the AR camera for battery / teardown. Call when dismissing AR navigation — not from `measurementReset` / `deactivate()`.
    func pauseARSession() {
        arview.session.pause()
    }

    /// Runs world tracking so the navigation camera preview works before UWB connects and after `pauseARSession()`.
    func runARSessionForNavigationUI() {
        let arkit_config = navigationARConfiguration()
        arview.session.run(arkit_config, options: [])
    }

    private func navigationARConfiguration() -> ARWorldTrackingConfiguration {
        let arkit_config = ARWorldTrackingConfiguration()
        arkit_config.planeDetection = [.horizontal]
        arkit_config.environmentTexturing = .none
        arkit_config.worldAlignment = .gravityAndHeading
        return arkit_config
    }
    
    private func clearGpsFixedWorldAnchor() {
        gpsFixedWorldTarget = nil
        lastGpsAnchorCoordinate = nil
    }
    
    private func shouldResnapGpsAnchor(for current: CLLocationCoordinate2D) -> Bool {
        guard let last = lastGpsAnchorCoordinate else { return true }
        let a = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let b = CLLocation(latitude: last.latitude, longitude: last.longitude)
        return a.distance(from: b) >= gpsResnapAfterMetersMoved
    }
    
    private func sendNIDiscoveryToken() {
        guard let token = niDiscoveryToken else { return }
        let data = try! NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
        
        let message = PeerToPeerMessage(identifier: "NIToken", data: data)
        let encoded = try? JSONEncoder().encode(message)
        
        try? mcSession.send(
            encoded!,
            toPeers: mcSession.connectedPeers,
            with: .reliable
        )
    }
    
    private func startNISession(token: NIDiscoveryToken) {
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession.run(config)
        
        if status != PeerToPeerStatus.Discovered {
            return
        }
        status = PeerToPeerStatus.Navigating
        
        let arkit_config = navigationARConfiguration()
        arview.session.run(
            arkit_config,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )
    }
    
    private func accumulateDatapoints(position: SIMD3<Float>, distance: Float) {
        // keep number of points strictly <= 5, lazy approach
        // a better clustering algorithm or sampling might be
        // better, but will be really hard and time consuming
        // to implement a good and efficient one :(
        if positionCollected.count >= 5 {
            positionCollected.removeFirst()
            distanceCollected.removeFirst()
        }
        
        // check the data points are not too close. if it is, the
        // math will be more sensitive to noise
        // the first point doesn't really matter since it is there
        // to make the algebra cleaner
        for point in positionCollected.dropFirst() {
            if simd_length(position - point) < MINIMUM_MEASUREMENT_DISTANCE {
                return
            }
        }
        
        // ensure the three points (excluding first point) forms
        // a triangle. Geometry is important to be more resiliant
        // to sensor noise
        if positionCollected.count == 3 {
            let ab = simd_normalize(position - positionCollected[1])
            let ac = simd_normalize(position - positionCollected[2])
            let abs_dot_prod = abs(simd_dot(ab, ac))
            if abs_dot_prod > (1.0 - DATAPOINT_ANGLE_THRESHOLD) {
                return
            }
        } else if positionCollected.count == 4 {
            // ensure the four points form a tetrhedron
            let ab = simd_normalize(positionCollected[2] - positionCollected[1])
            let ac = simd_normalize(positionCollected[3] - positionCollected[1])
            let ad = simd_normalize(position - positionCollected[1])
            let ref = simd_cross(ab, ac)
            let abs_dot_prod = abs(simd_dot(ref, ad))
            if abs_dot_prod < DATAPOINT_ANGLE_THRESHOLD {
                return
            }
        }
        
        // the datapoint pass all the test, we can append it now :)
        positionCollected.append(position)
        distanceCollected.append(distance)
    }
    
    private func evaluatePosition() {
        // not enough data points
        if positionCollected.count < 5 {
            return
        }
        
        // using least squares, as for the parameters, I would need to show
        // my work, can't really explain it here
        let reference: SIMD3<Float> = positionCollected[0]
        let referenceDistanceSq: Float = distanceCollected[0] * distanceCollected[0]
        let referenceSelfDotProd: Float = simd_dot(positionCollected[0], positionCollected[0])

        let A = simd_float3x4(rows: [
            positionCollected[1] - reference,
            positionCollected[2] - reference,
            positionCollected[3] - reference,
            positionCollected[4] - reference
        ])
        var y: SIMD4<Float> = .zero
        for i in 0..<4 {
            let distSq: Float = distanceCollected[i + 1] * distanceCollected[i + 1]
            let selfDotProd: Float = simd_dot(positionCollected[i + 1], positionCollected[i + 1])
            y[i] = referenceDistanceSq - distSq + selfDotProd - referenceSelfDotProd
        }
        
        let At = simd_transpose(A)
        let gram = At * A
        let invGram = simd_inverse(gram)
        let delta = invGram * At * y
        if !delta.x.isFinite || !delta.y.isFinite || !delta.z.isFinite {
            return
        }
        multilaterationSum += delta
        multilaterationCount += 1
        hasData = true
    }
}

extension NearbyNavigationService: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // retrieve the distance/direction
        guard let niObject = nearbyObjects.first else { return }
        let now = CACurrentMediaTime()
        if now - lastNIProcessMediaTime < niUpdateMinInterval {
            return
        }
        lastNIProcessMediaTime = now
        
        let distanceOpt: Float? = niObject.distance
        let directionOpt = niObject.direction
        
        // retrieve the position
        guard let imageFrame = arview.session.currentFrame else { return }
        let transform = imageFrame.camera.transform
        let position: SIMD3<Float> = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z)
        
        // The first measurement is unreliable for some reason, discovered that empirically,
        // could be placebo, :/ but better to not have this point than to risk it
        if simd_length(position) < 0.001 {
            return
        }

        // Priority 1: if UWB direction AND distance available, use direct target.
        if let distance = distanceOpt, let direction = directionOpt {
            clearGpsFixedWorldAnchor()
            niDistanceMeters = distance
            uwbDirection = direction
            uwbHasDirection = true
            directTargetWorld = Self.worldTargetFromUWB(cameraTransform: transform, cameraPosition: position, direction: direction, distance: distance)
            hasData = true
            // `target` / `targetDistance` are finalized in `updateBestTargetEstimate` each frame.
            return
        }

        // Priority 2: if only UWB distance available, use multilateration.
        if let distance = distanceOpt {
            clearGpsFixedWorldAnchor()
            niDistanceMeters = distance
            uwbDirection = nil
            uwbHasDirection = false
            directTargetWorld = nil
            accumulateDatapoints(position: position, distance: distance)
            evaluatePosition()
            return
        }

        // Priority 3 (GPS) is applied in `updateBestTargetEstimate` when UWB data is missing.
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        // TODO: test this error
        // Nearby Interaction Failed, should deactivate
        deactivate()
        broadcastUser()
    }
}

extension NearbyNavigationService {
    /// Call once per AR frame (e.g. from `ARView`’s display link) so `target` and `targetDistance` reflect UWB → multilateration → GPS priority.
    func updateBestTargetEstimate(cameraTransform: simd_float4x4) {
        let resolved = resolveBestEstimate(cameraTransform: cameraTransform)
        target = resolved.targetWorld
        targetDistance = resolved.distanceMeters
        navigationSourceMode = resolved.mode
    }

    static func worldTargetFromUWB(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>, direction: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
        let localDir = simd_normalize(direction)
        let worldDir4 = cameraTransform * SIMD4<Float>(localDir.x, localDir.y, localDir.z, 0.0)
        let worldDir = SIMD3<Float>(worldDir4.x, worldDir4.y, worldDir4.z)
        return cameraPosition + (simd_normalize(worldDir) * distance)
    }

    /// Camera look direction projected onto the horizontal plane (perpendicular to camera “up”), for a coarse “along‑range” hint before multilateration converges.
    private static func horizontalForward(cameraTransform: simd_float4x4) -> SIMD3<Float> {
        let forward = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        let up = SIMD3<Float>(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z)
        let g = simd_normalize(up)
        var f = forward - g * simd_dot(forward, g)
        if simd_length_squared(f) < 1e-8 { return simd_normalize(forward) }
        return simd_normalize(f)
    }

    static func worldOffsetFromGPS(current: CLLocationCoordinate2D, target: CLLocationCoordinate2D) -> (eastMeters: Double, northMeters: Double) {
        // Convert to a local tangent plane approximation (E/N meters).
        let origin = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let northPoint = CLLocation(latitude: target.latitude, longitude: current.longitude)
        let eastPoint = CLLocation(latitude: current.latitude, longitude: target.longitude)

        let north = northPoint.distance(from: origin) * (target.latitude >= current.latitude ? 1.0 : -1.0)
        let east = eastPoint.distance(from: origin) * (target.longitude >= current.longitude ? 1.0 : -1.0)
        return (east, north)
    }

    /// Resolve the best available navigation target in AR world space.
    /// Priority:
    /// 1) UWB direction + distance
    /// 2) UWB distance via multilateration (after enough samples)
    /// 3) UWB distance only — coarse hint along horizontal look axis while multilateration warms up (avoids GPS masking active ranging)
    /// 4) GPS if local `gps` and peer `targetGPS` exist (`targetGPS` comes from `targetUser`’s last-known lat/lng)
    private func resolveBestEstimate(cameraTransform: simd_float4x4) -> (targetWorld: SIMD3<Float>, distanceMeters: Float, mode: NavigationSourceMode) {
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        if let direct = directTargetWorld, uwbHasDirection {
            let d = niDistanceMeters ?? 0
            if d > 0 {
                clearGpsFixedWorldAnchor()
                return (direct, d, .uwbDirect)
            }
        }

        if multilaterationCount > 0 {
            clearGpsFixedWorldAnchor()
            let geom = simd_length(multilaterationEstimate - cameraPosition)
            let d = (niDistanceMeters ?? 0) > 0 ? (niDistanceMeters ?? 0) : geom
            return (multilaterationEstimate, d, .uwbMultilateration)
        }

        // Nearby Interaction is providing range but multilateration has not solved yet — GPS was incorrectly winning here before.
        if status == .Navigating, let d = niDistanceMeters, d > 0, multilaterationCount == 0 {
            clearGpsFixedWorldAnchor()
            let f = Self.horizontalForward(cameraTransform: cameraTransform)
            let roughTarget = cameraPosition + f * d
            return (roughTarget, d, .uwbCalibrating)
        }

        // During an active NI navigation session, peer lat/lng is usually a stale server snapshot. When UWB drops a few
        // updates (throttling, orientation, or a nil `distance` frame), falling through to GPS shows bogus range (~100s m)
        // and bearings like “west” while the friend is actually beside you.
        if status == .Navigating {
            clearGpsFixedWorldAnchor()
            return (cameraPosition, 0.0, .unavailable)
        }

        if let currentGPS = gps, let destGPS = targetGPS {
            if gpsFixedWorldTarget == nil || shouldResnapGpsAnchor(for: currentGPS) {
                let en = Self.worldOffsetFromGPS(current: currentGPS, target: destGPS)
                let y = Float(targetAltitude - altitude)
                // With `gravityAndHeading`, treat +X as East and -Z as North. Snap once per anchor, not every frame from camera (that pinned distance).
                gpsFixedWorldTarget = cameraPosition + SIMD3<Float>(Float(en.eastMeters), y, Float(-en.northMeters))
                lastGpsAnchorCoordinate = currentGPS
            }
            guard let fixed = gpsFixedWorldTarget else {
                return (cameraPosition, 0.0, .unavailable)
            }
            let geomDist = simd_length(fixed - cameraPosition)
            return (fixed, geomDist, .gps)
        }

        return (cameraPosition, 0.0, .unavailable)
    }
}

extension NearbyNavigationService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // TODO: double check my changes, do we stop advertising/browsing?
        switch state {
        case .connected:
            sendNIDiscoveryToken()
        case .notConnected:
            deactivate()
            broadcastUser()
        default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let message = try! JSONDecoder().decode(PeerToPeerMessage.self, from: data)
        if let token = try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: message.data
        ) {
            startNISession(token: token)
        }
    }
    
    func session(_ session: MCSession, didReceive certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
    
    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {
        // TODO: probably no implementation needed
    }
    
    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {
        // TODO: probably no implementation needed
    }
    
    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {
        // TODO: probably no implementation needed
    }
}

extension NearbyNavigationService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // TODO: do we want to stop advertising when found?
        invitationHandler(true, mcSession)
        // mcAdvertiser.stopAdvertisingPeer()
        status = PeerToPeerStatus.Discovered
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        // unable to advertise self, should deactivate and try again
        deactivate()
        broadcastUser()
    }
}

extension NearbyNavigationService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        if peerID.displayName != targetUser?.userId.uuidString {
            return
        }
        
        status = PeerToPeerStatus.Discovered
        mcBrowser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if peerID.displayName != targetUser?.userId.uuidString {
            return
        }
        status = PeerToPeerStatus.Searching
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        // unable to browse for users, should deactivate and try again
        deactivate()
        searchUsers()
    }
}
