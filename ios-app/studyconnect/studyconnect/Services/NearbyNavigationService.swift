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

@Observable
class NearbyNavigationService: NSObject {
    let MINIMUM_MEASUREMENT_DISTANCE: Float = 0.3
    let DATAPOINT_ANGLE_THRESHOLD: Float = 0.15
    private(set) var status: PeerToPeerStatus = PeerToPeerStatus.Inactive
    
    private var currentUser: UserProfile
    public var targetUser: UserProfile? = nil
    private var foundUsers: [MCPeerID: UserProfile] = [
        // dummy data
        MCPeerID(displayName: "aaaa"): UserProfile(userId: UUID(), displayName: "Alice Johnson",  email: "alice@umich.edu", studySpot: "Engineering Building", distanceMiles: 0.2),
        MCPeerID(displayName: "bbbb"): UserProfile(userId: UUID(), displayName: "Bob Smith",      email: "bob@umich.edu",   studySpot: "Library",             distanceMiles: 0.5)
    ]
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
    private var targetSum: SIMD3<Float> = .zero
    private var targetMeasurementCount: Float = 0.0
    private(set) var targetDistance: Float = 0.0
    var target: SIMD3<Float> {
        get {
            return targetMeasurementCount > 0 ? targetSum / targetMeasurementCount : SIMD3<Float>(0.0, 0.0, 0.0)
        }
    }
    private(set) var gps: CLLocationCoordinate2D? = nil
    
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
                    // TODO: remove time and userid
                    let time: Double = Date().timeIntervalSince1970
                    let userid: String = self.currentUser.id.uuidString
//                    print("\(userid) at \(time): \(data!.altitude)")
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
            status = PeerToPeerStatus.Inactive
        }
    }
    
    private func measurementReset() {
        // TODO: double check
        altitude = 0.0
        targetMeasurementCount = 0.0
        targetSum = .zero
        positionCollected = []
        distanceCollected = []
        hasData = false
        arview.session.pause()
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
        
        // start ARView
        let arkit_config = ARWorldTrackingConfiguration()

        arkit_config.planeDetection = [.horizontal, .vertical]
        arkit_config.environmentTexturing = .automatic
        arkit_config.worldAlignment = .gravityAndHeading
        
        arview.session.run(
            arkit_config,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )
    }
    
    private func accumulateDatapoints(position: SIMD3<Float>, distance: Float) {
        print(positionCollected.count)
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
            print("three")
            print(abs_dot_prod)
            if abs_dot_prod > (1.0 - DATAPOINT_ANGLE_THRESHOLD) {
                print(abs_dot_prod)
                return
            }
        } else if positionCollected.count == 4 {
            // ensure the four points form a tetrhedron
            let ab = simd_normalize(positionCollected[2] - positionCollected[1])
            let ac = simd_normalize(positionCollected[3] - positionCollected[1])
            let ad = simd_normalize(position - positionCollected[1])
            let ref = simd_cross(ab, ac)
            let abs_dot_prod = abs(simd_dot(ref, ad))
            print("four")
            print(abs_dot_prod)
            if abs_dot_prod < DATAPOINT_ANGLE_THRESHOLD {
                print(abs_dot_prod)
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
        targetSum += simd_inverse(At * A) * At * y
        targetMeasurementCount += 1
        
        print("discovered target")
        print(target)
        hasData = true
    }
}

extension NearbyNavigationService: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // retrieve the distance
        guard let niObject = nearbyObjects.first else { return }
        let distance: Float! = niObject.distance ?? 0.0
        
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
        
        targetDistance = distance
        accumulateDatapoints(position: position, distance: distance)
        evaluatePosition()
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        // TODO: test this error
        // Nearby Interaction Failed, should deactivate
        deactivate()
        broadcastUser()
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
