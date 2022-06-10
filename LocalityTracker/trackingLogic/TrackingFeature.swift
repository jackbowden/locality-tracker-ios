//
//  TrackingFeature.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 2/18/22.
//

import Foundation
import CoreLocation
import Turf
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

/// Wrapper for received localities that track their statistics relevant to the user such as distance and if the user is inside or not
class TrackingFeature: Equatable, Codable {
    //let parentLayer: TrackingLayer //i feel like this is going to bite me in the ass someday //JULY 15TH WAS THE DAY
    
    let layername: String
    var info: LayerAPIResponse.Locality.Info
    var isInside: Bool // TODO: do i still like the private(set) thing?
        
    var enteringSoundBool: Bool = true
    var exitingSoundBool: Bool = false
    
    var setDistances: [DistanceAlert] = [.oneFourthAMile, .halfAMile, .oneMile, .twoMiles]
    var soundedDistances: [DistanceAlert] = []
    var resetDistance: Double = DistanceAlert.twoMiles.rawValue
    
    var closestRoadCrossingDistance: Double?
    var directDistance: Double?
        
    /// Descripes distances that localities may be alerted to
    enum DistanceAlert: Double, Codable {
        case oneFourthAMile = 400
        case halfAMile = 800
        case oneMile = 1600
        case twoMiles = 3200
    }
    
    init(layername: String, locality: LayerAPIResponse.Locality, alertStartLocation: CLLocation) {
        self.layername = layername
        self.info = locality.info
        self.isInside = locality.isinside
        let answer = info.getDistance(alertStartLocation)
        self.directClosestCoordinate = answer.0
        self.directDistance = answer.1
    }
    
    static func == (lhs: TrackingFeature, rhs: TrackingFeature) -> Bool {
        return lhs.info.gid == rhs.info.gid
    }
    
    struct collectedLocalityUpdate {
        let status: LocalityUpdate
        let alert: AlertReport?
    }
    
    enum LocalityUpdate {
        case hasEntered, hasLeft, stillInside, stillOutside
    }
    
    
    private var closestRoadCrossingLatitude: Double = 0.0
    private var closestRoadCrossingLongtitude: Double = 0.0
    private(set) public var closestRoadCrossingCoordinate: CLLocationCoordinate2D? {
        get {
            if self.closestRoadCrossingLatitude == 0.0 && self.closestRoadCrossingLongtitude == 0.0 {
                return nil
            }
            return CLLocationCoordinate2D(latitude: closestRoadCrossingLatitude, longitude: closestRoadCrossingLongtitude)
        }
        set {
            self.closestRoadCrossingLatitude = newValue?.latitude ?? 0.0
            self.closestRoadCrossingLongtitude = newValue?.longitude ?? 0.0
        }
    }
    
    private var directClosestCoordinateLatitude: Double = 0.0
    private var directClosestCoordinateLongtitude: Double = 0.0
    private(set) public var directClosestCoordinate: CLLocationCoordinate2D? {
        get {
            if self.directClosestCoordinateLatitude == 0.0 && self.directClosestCoordinateLongtitude == 0.0 {
                return nil
            }
            return CLLocationCoordinate2D(latitude: directClosestCoordinateLatitude, longitude: directClosestCoordinateLongtitude)
        }
        set {
            self.directClosestCoordinateLatitude = newValue?.latitude ?? 0.0
            self.directClosestCoordinateLongtitude = newValue?.longitude ?? 0.0
        }
    }
    
    
    
    func newTrackingLocation(_ loc: CLLocation, _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?) -> collectedLocalityUpdate {
        
        var status: LocalityUpdate? = nil
        closestRoadCrossingCoordinate = nil
        closestRoadCrossingDistance = nil
        
        let isInsideAnswer = info.isInside(loc, certainty: true)
        
        var finalRoadName = ""
        var currentRoadCode = ""
        var currentRoadName = ""
        
        var onLine = false
        
        directDistance = isInsideAnswer.distance
        directClosestCoordinate = isInsideAnswer.closestDirectCoordinate
        
        if isInsideAnswer.isCertain {
            switch isInsideAnswer.answer {
            case true:
                if !self.isInside {
                    self.isInside = true
                    status = .hasEntered
                } else {
                    status = .stillInside
                }
            case false:
                if self.isInside {
                    self.isInside = false
                    status = .hasLeft
                } else {
                    status = .stillOutside
                }
            }
        } else {
            if self.isInside {
                status = .stillInside
            } else {
                status = .stillOutside
            }
        }
        
        if status == .hasLeft {
            while !soundedDistances.isEmpty {
                setDistances.append(soundedDistances.removeFirst())
            }
        }
        
        guard let horizon = horizon,
              let passiveLocationManager = passiveLocationManager
        else { return collectedLocalityUpdate(status: status!, alert: nil) }
        
        var alertReport: AlertReport?
        var intEdge: HelperFunctions.IntEdge?
        
        // MARK: The part that does the road approach checking
        if !self.isInside && isInsideAnswer.distance <= resetDistance {
            // TODO: improve findEdgeIntersection to make it return an array of identified intersections so we can determine if we're close to crossing out of the boundary again (for the NWS Yorktown/Craney Island problem)
            
            // TODO: implement probability of identified intersection and dont alert if its less than 50% for example, also implement telling if intersection is dead ahead or not
            //if passiveLocationManager.roadGraph.edgeMetadata(edgeIdentifier: currentEdge?).probability
            
            if let identifiedIntersection = HelperFunctions.findEdgeIntersectionWithLocality(passiveLocationManager, horizon, info, nil) {
                intEdge = identifiedIntersection
                onLine = true
                
                closestRoadCrossingDistance = identifiedIntersection.distance
                closestRoadCrossingCoordinate = identifiedIntersection.intersectionPoint
                
                if let currentEdge = passiveLocationManager.roadGraph.edgeMetadata(edgeIdentifier: identifiedIntersection.roadEdge.identifier) {
                    
                    for name in currentEdge.names {
                        switch name {
                        case .name(let name):
                            if currentRoadName == "" {
                                currentRoadName = name
                            }
                            //print("Road name: \(name)")
                        case .code(let code):
                            if currentRoadCode == "" {
                                currentRoadCode = code
                            } else {
                                currentRoadCode += " \(code)"
                            }
                            //print("Road code: \(code)")
                        }
                    }
                    if currentRoadCode != "" && currentRoadName != "" {
                        finalRoadName = currentRoadCode + " " + currentRoadName
                    } else {
                        finalRoadName = currentRoadCode + currentRoadName
                    }
                }
                
                // WARNING: identified intersection in below statement might bite me in the ass. may want to use horizon again.
                // TODO: could make this a "while not nil, keep accruing IntEdges in an array" kind of situation
                
                //if let nextOne = HelperFunctions.findEdgeIntersectionWithLocality(passiveLocationManager, identifiedIntersection.roadEdge, info, [identifiedIntersection.intersectionPoint]) {
                if let nextOne = HelperFunctions.findEdgeIntersectionWithLocality(passiveLocationManager, horizon, info, [identifiedIntersection.intersectionPoint]) {
                                    
                    //let speedOfDeviceInMPH = (loc.speed * 60 * 60)/1609.0
                    //var newLine = LineString(identifiedIntersection.polylineToIntersection.coordinates)
                    //newLine.coordinates.append(contentsOf: nextOne.polylineToIntersection.coordinates)
                    
                    let nextOneMeta = passiveLocationManager.roadGraph.edgeMetadata(edgeIdentifier: nextOne.roadEdge.identifier)
                    let theSpeed = (nextOneMeta?.speed ?? nextOneMeta?.speedLimit?.converted(to: .metersPerSecond).value) ?? loc.speed
                    //print("Chosen speed: \(theSpeed)")
                    //let sliceLine = nextOne.polylineToIntersection.sliced(from: identifiedIntersection.intersectionPoint, to: nextOne.intersectionPoint)?.distance()
                    
                    //let otherLine = identifiedIntersection.intersectionPoint.distance(to: nextOne.intersectionPoint)
                    let subtraction = abs(identifiedIntersection.distance-nextOne.distance)
                    
//                    print("Slice Line dist: \(sliceLine)")
//                    print("Other Line dist: \(otherLine)")
//                    print("Subtraction: \(subtraction)") // why is this sometimes a negative number???
                    
                    // TODO: make it distance between intersecting points on road distance, not as the crow flies
                    if (theSpeed * 4 > subtraction ) {
                        //print("GOING TOO FAST TO NOT BE IN \(info.name) \(layername) FOR 4 SECONDS. DONT ALERT.")
                        return collectedLocalityUpdate(status: status!, alert: nil) // warning: returning this early will probably prove to be super inconvienent and problematic
                    }
                }
            }
        }
        
//        while !soundedDistances.isEmpty && directDistance ?? 0 > soundedDistances.last!.rawValue {
//            setDistances.append(soundedDistances.popLast()!)
//        }
        
        // silly idea but desperate
        if setDistances.first == .twoMiles {
            soundedDistances.removeAll()
            setDistances = [.oneFourthAMile, .halfAMile, .oneMile, .twoMiles]
        }
        
        // MARK: Scan and assemble possible alerts
        if let lastKnownDistance = intEdge?.distance { // lastKnownRoadCrossingDistance ?? directDistance {
            
            if isInsideAnswer.isCertain && !isInsideAnswer.answer && onLine { // TODO: this "onLine" thing is not gonna work for alerting me to boundary crossings if the phone has no internet to download more map data
                
                // reset distances that we have driven far enough away from
                while !soundedDistances.isEmpty && lastKnownDistance > soundedDistances.last!.rawValue && (lastKnownDistance != directDistance && lastKnownDistance < directDistance ?? 0) {
                    setDistances.append(soundedDistances.popLast()!)
                }
                
                // TODO: implement probablity starting here
                while !setDistances.isEmpty && setDistances.last!.rawValue >
                        lastKnownDistance { // TODO: might bite me in the ass later
                    
                    let candidate = setDistances.popLast()
                    soundedDistances.append(candidate!)
                    if finalRoadName != "" {
                        alertReport = AlertReport(alertingFeature: self, alertType: candidate!, finalRoadName: finalRoadName)
                    } else {
                        alertReport = AlertReport(alertingFeature: self, alertType: candidate!)
                    }
                }
            }
        }
        
        
        return collectedLocalityUpdate(status: status!, alert: alertReport)
    }
    
    func getExistingStatus(_ loc: CLLocation) -> LocalityUpdate {
        if self.isInside {
            return .stillInside
        }
        return .stillOutside
    }
    
    func neuter() {
        soundedDistances.append(contentsOf: setDistances)
        setDistances.removeAll()
    }
    
    struct AlertReport: Equatable, Codable {
        let alertingFeature: TrackingFeature
        var alertType: DistanceAlert
        var soundAlert: Bool = true
        var finalRoadName: String? = ""
        
        static func == (lhs: AlertReport, rhs: AlertReport) -> Bool {
            return lhs.alertingFeature == rhs.alertingFeature
        }
    }
}
