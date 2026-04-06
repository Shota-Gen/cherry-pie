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

enum PeerToPeerStatus {
    case Inactive
    case Broadcasting
    case Searching
    case BroadcastConnecting
    case SearchConnecting
    case Navigating
    case Approached
}

struct PeerToPeerMessage: Codable {
    let identifier: String
    let data: Data
}

@Observable
class NearbyNavigationService: NSObject {
    let MINIMUM_MEASUREMENT_DISTANCE: Float = 0.3
    let DATAPOINT_ANGLE_THRESHOLD: Float = 0.15
    private(set) var peerToPeerStatus: PeerToPeerStatus = PeerToPeerStatus.Inactive
    
    private var commitedUser: MCPeerID? = nil
    private var foundUsers: [MCPeerID: UserProfile] = [
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
    private var myAltitude: Double = 0.0
    private var targetAltitude: Double = 0.0
    
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
    
    // peer to peer variables
    public var myPeerId: MCPeerID = MCPeerID(displayName: "unknown" + UUID().uuidString)
    var userId: String {
        get {
            return myPeerId.displayName
        }
        set {
            myPeerId = MCPeerID(displayName: newValue)
        }
    }
    
    private var mcSession: MCSession!
    private var mcAdvertiser: MCNearbyServiceAdvertiser!
    private var mcBrowser: MCNearbyServiceBrowser!
    
    // nearby interaction variables
    private var niSession: NISession!
    private var niDiscoveryToken: NIDiscoveryToken!
    
    override init() {
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
    }
    
    func broadcastUser() {
        if peerToPeerStatus != PeerToPeerStatus.Inactive {
            deactivate()
        }

        mcAdvertiser.startAdvertisingPeer()
        peerToPeerStatus = PeerToPeerStatus.Broadcasting
    }
    
    func searchUsers() {
        if peerToPeerStatus != PeerToPeerStatus.Inactive {
            deactivate()
        }
        
        mcBrowser.startBrowsingForPeers()
        peerToPeerStatus = PeerToPeerStatus.Searching
    }
    
    func invitePeer(peer: UUID) {
        if peerToPeerStatus != PeerToPeerStatus.Searching {
            return
        }
        
        for (userPeerId, userProf) in foundUsers {
            if userProf.userId.uuidString == peer.uuidString {
                mcBrowser.invitePeer(userPeerId, to: mcSession, withContext: nil, timeout: 10)
            }
        }
    }

    func deactivate() {
        measurementReset()
        switch peerToPeerStatus {
        case .Inactive:
            return
        case .Broadcasting:
            mcAdvertiser.stopAdvertisingPeer()
            peerToPeerStatus = PeerToPeerStatus.Inactive
            return
        case .Searching:
            mcBrowser.stopBrowsingForPeers()
            peerToPeerStatus = PeerToPeerStatus.Inactive
            return
        default:
            break
        }
    }
    
    private func measurementReset() {
        print("reset")
        myAltitude = 0.0
        targetAltitude = 0.0
        targetMeasurementCount = 0.0
        targetSum = .zero
        positionCollected = []
        distanceCollected = []
        hasData = false
        arview.session.pause()
        //altimeter.stopAbsoluteAltitudeUpdates()
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
        
        if peerToPeerStatus != PeerToPeerStatus.Navigating {
            return
        }
        
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
        
//        if CMAltimeter.isRelativeAltitudeAvailable() {
//            altimeter.startAbsoluteAltitudeUpdates(to: .main, withHandler: { data, error in
//                print("altitude????")
//                if data != nil {
//                    print(data!.altitude)
//                    self.myAltitude = data!.altitude
//                }
//            })
//        }
        
//        altimeterStreamingTimer = Timer.scheduledTimer(
//            withTimeInterval: 1.0,
//            repeats: true,
//            block: { [weak self] _ in
//                self?.sendAltitudeReadings()
//            })
    }
    
    private func sendAltitudeReadings() {
        let altitudeData: Data = Data(bytes: &myAltitude, count: MemoryLayout<Double>.size)
        let message = PeerToPeerMessage(identifier: "AltitudeReading", data: altitudeData)
        let encoded = try? JSONEncoder().encode(message)
        
        try? mcSession.send(
            encoded!,
            toPeers: mcSession.connectedPeers,
            with: .reliable
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
        print("Ni session invalided, deactivating")
        deactivate()
    }
}

extension NearbyNavigationService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            if peerToPeerStatus == PeerToPeerStatus.Broadcasting {
                //mcAdvertiser.stopAdvertisingPeer()
                peerToPeerStatus = PeerToPeerStatus.BroadcastConnecting
            } else if peerToPeerStatus == PeerToPeerStatus.Searching {
                //mcBrowser.stopBrowsingForPeers()
                peerToPeerStatus = PeerToPeerStatus.SearchConnecting
            }
            commitedUser = peerID
            sendNIDiscoveryToken()
        case .notConnected:
            deactivate()
            commitedUser = nil
        default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let message = try! JSONDecoder().decode(PeerToPeerMessage.self, from: data)
        if message.identifier == "NIToken" {
            if let token = try! NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: message.data
            ) {
                if peerToPeerStatus == PeerToPeerStatus.BroadcastConnecting {
                    peerToPeerStatus = PeerToPeerStatus.Approached
                } else if peerToPeerStatus == PeerToPeerStatus.SearchConnecting {
                    peerToPeerStatus = PeerToPeerStatus.Navigating
                }
                startNISession(token: token)
            }
        } else if message.identifier == "AltitudeReading" {
            targetAltitude = message.data.withUnsafeBytes {
                $0.load(as: Double.self)
            }
            
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
        invitationHandler(true, mcSession)
        mcAdvertiser.stopAdvertisingPeer()
        peerToPeerStatus = PeerToPeerStatus.BroadcastConnecting
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        print("Advertiser has failed!")
    }
}

extension NearbyNavigationService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        print("found user")
        // TODO: FINISH IMPLEMENTATION, lookup user, don't add if don't exist
        if peerID == myPeerId {
            return
        }
        foundUsers[peerID] = UserProfile(userId: UUID(), displayName: "SpongeBob",  email: "spongebob@umich.edu", studySpot: "Engineering Building", distanceMiles: 0.2)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // the user is no longer searchable, remove them
        print("user disconnected")
//        foundUsers.removeValue(forKey: peerID)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        print("Browser has failed!")
    }
}
