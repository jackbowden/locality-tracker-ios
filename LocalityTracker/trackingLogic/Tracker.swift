//
//  Tracker.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/1/22.
//

import Foundation
import CoreLocation
import Turf
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

/// Manages tracking of localities with user location, provides reports through delegate.
class Tracker {
    
    public weak var delegate: TrackerDelegate?
    
    var passiveLocationManager: PassiveLocationManager = PassiveLocationManager()
    
    var trackingLayers: [TrackingLayer] = []
    
    private let queryQueue = DispatchQueue(label: "me.jackbowden.LocalityTrackerNav.queryqueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: .none)
    private let queryGroup = DispatchGroup()
    private let ehpGuard = DispatchQueue(label: "me.jackbowden.LocalityTrackerNav.ehpGuard", attributes: .concurrent)
    var layerProcessingQueue: DispatchQueue = DispatchQueue(label: "me.jackbowden.LocalityTrackerNav.layerqueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: .none)
    var queryAllLayersIsReady = true
    
    var layers: [String] = ["us_states", "us_counties", "us_places", "us_zip_places", "us_military_bases"]
    //var layers: [String] = ["us_counties", "us_zip_places"]
    
    var screecher = Screecher(vocal: UserDefaults.standard.bool(forKey: "mute_preference"))
    var notifier = Notifier()
    
    var lastLocalityReport: LocalityReport?

    private var _lastKnownEHPHorizion: RoadGraph.Edge?
    private var _lastKnownEHPPosition: RoadGraph.Position?
    private var _lastKnownEHPDistances: [DistancedRoadObject]?
    var lastKnownEHPHorizon: RoadGraph.Edge? {
        
        var copy: RoadGraph.Edge? = nil
        ehpGuard.sync {
            if self._lastKnownEHPHorizion != nil {
                copy = self._lastKnownEHPHorizion!
            }
        }
        return copy
    }
    
    var lastKnownEHPPosition: RoadGraph.Position? {
        
        var copy: RoadGraph.Position? = nil
        ehpGuard.sync {
            if self._lastKnownEHPHorizion != nil {
                copy = self._lastKnownEHPPosition!
            }
        }
        return copy
    }
    
    var lastKnownEHPDistances: [DistancedRoadObject]? {
        
        var copy: [DistancedRoadObject]? = nil
        ehpGuard.sync {
            if self._lastKnownEHPDistances != nil {
                copy = self._lastKnownEHPDistances!
            }
        }
        return copy
    }
    
    public required init(dumpSavedLayers: Bool? = false) {
        //passiveLocationManager.delegate = self
        if passiveLocationManager.systemLocationManager.authorizationStatus == .notDetermined || passiveLocationManager.systemLocationManager.authorizationStatus == .denied {
            return
        }
        
        passiveLocationManager.roadObjectMatcher.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateEHP), name: .electronicHorizonDidUpdatePosition, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateRoadName), name: .currentRoadNameDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateLocation), name: .passiveLocationManagerDidUpdate, object: nil)
        
        if dumpSavedLayers! {
            self.dumpSavedLayers()
            //self.populateLayers()
        }
        updateTrackerSettings()
    }
    
    public func dumpSavedLayers() {
        print("Dumping layers.")
        for layer in trackingLayers {
            UserDefaults.standard.removeObject(forKey: "\(layer.name) layer")
        }
        
        for layer in layers {
            UserDefaults.standard.removeObject(forKey: "\(layer) layer")
        }
        
        self.trackingLayers = []
    }
    
    public func startTracking() {
        if UserDefaults.standard.bool(forKey: "demo_mode") {
            
            passiveLocationManager.systemLocationManager.stopUpdatingHeading()
            passiveLocationManager.systemLocationManager.stopUpdatingLocation()
        } else {
            passiveLocationManager.startUpdatingLocation()
            passiveLocationManager.systemLocationManager.requestLocation()
            passiveLocationManager.systemLocationManager.startUpdatingLocation()
            passiveLocationManager.systemLocationManager.startUpdatingHeading()
        }
        passiveLocationManager.resumeTripSession()
        
        passiveLocationManager.systemLocationManager.allowsBackgroundLocationUpdates = true
        
        passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: nil)) // was nil //3600
        
        // TODO: setup notification center for passivemanager's updates instead of the delegate method we have right now
        
        populateLayers()
    }
    
    public func populateLayers() {
        print("Populating.")
        for layer in layers {
            //UserDefaults.standard.removeObject(forKey: "\(layer) layer") //THIS IS FOR DEBUGGING MODE
            if !trackingLayers.contains(where: {tR in tR.name == layer}) {
                if let loadingLayer = UserDefaults.standard.data(forKey: "\(layer) layer") {
                    do {
                        let decodedLayer = try JSONDecoder().decode(TrackingLayer.self, from: loadingLayer)
                        trackingLayers.append(decodedLayer)
                        print("Successfully decoded normal \(layer) layer")
                    } catch {
                        print("Unable to decode layer \(layer): \(error)")
                        trackingLayers.append(TrackingLayer(range: 15, name: layer))
                    }
                } else {
                    trackingLayers.append(TrackingLayer(range: 15, name: layer))
                }
            }
        }
    }
    
    public func stopTracking() {
        //passiveLocationManager.updateLocation(passiveLocationManager.location)
        passiveLocationManager.systemLocationManager.allowsBackgroundLocationUpdates = false
        passiveLocationManager.stopUpdatingElectronicHorizon()
        passiveLocationManager.pauseTripSession()
        delegate?.trackerTurnedOff()
    }
    
    public func updateTrackerSettings() {
        if UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
            startTracking()
        } else {
            stopTracking()
        }
    }
    
    var lastLocationTapped: CLLocation?
    var lastLocationSentToQueryingLayers: CLLocation?
    
    /// Generates and delivers locality report through delegate of requested location
    /// - Parameter location: Location to request a locality report of
    public func manuallyRequestLocalityReport(_ location: CLLocation, test: Bool? = false) {
        if !queryAllLayersIsReady {
            session.getAllTasks { tasks in
                for task in tasks {
                    print("Cancelling task for \(task.taskDescription ?? "IDK the task")")
                    task.cancel()
                }
            }
        }
        
        lastLocationTapped = location
        passiveLocationManager.updateLocation(location) { result in
            print(result)
        }
        if !test! {
            queryLayers(location, trackingLayers) // this is what makes it so snappy
        }
    }
    
    @objc func didUpdateEHP(_ notification: Notification) {
        guard
            let position = notification.userInfo?[RoadGraph.NotificationUserInfoKey.positionKey] as? RoadGraph.Position,
            let horizon = notification.userInfo?[RoadGraph.NotificationUserInfoKey.treeKey] as? RoadGraph.Edge,
            //let isThisSameMPP = notification.userInfo?[RoadGraph.NotificationUserInfoKey.updatesMostProbablePathKey] as? Bool,
            let distances = notification.userInfo?[RoadGraph.NotificationUserInfoKey.distancesByRoadObjectKey] as? [DistancedRoadObject]
        else { return }
        
        ehpGuard.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            self._lastKnownEHPPosition = position
        }
        
        ehpGuard.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            self._lastKnownEHPHorizion = horizon
        }
        
        ehpGuard.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            self._lastKnownEHPDistances = distances
        }
    }
}


/// Provides updates to the tracking interface.
protocol TrackerDelegate: AnyObject {
        
    func trackerHasNewLocalityReports(_ tracker: Tracker, localityReports: [LocalityReport], _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?)
    
    func trackerTurnedOff()
    
    func needsToCallNetwork()
    
    func networkReturnedWithData()
    
    func failedToGetLocationUpdate()
    
    func queryingLayers()

}

public struct LocalityReport: Equatable, Codable {
    let layer: TrackingLayer
    let latitude: Double
    let longitude: Double
    var enteredLocalities: [TrackingFeature] = []
    var exitedLocalities: [TrackingFeature] = []
    var currentLocalities: [TrackingFeature] = []
    var neighboringLocalities: [TrackingFeature] = []
    var approachingAlerts: [TrackingFeature.AlertReport] = []
    
    public static func == (lhs: LocalityReport, rhs: LocalityReport) -> Bool {
        return lhs.layer == rhs.layer // TODO: make sure this actually works
    }
    
    var coordinate: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

extension Tracker: RoadObjectMatcherDelegate {
    public func roadObjectMatcher(_ matcher: RoadObjectMatcher, didMatch roadObject: RoadObject) {
        passiveLocationManager.roadObjectStore.addUserDefinedRoadObject(roadObject)
        print("MATCHED \(roadObject.identifier)")
    }
    
    public func roadObjectMatcher(_ matcher: RoadObjectMatcher, didFailToMatchWith error: RoadObjectMatcherError) {
        return
    }
    
    public func roadObjectMatcher(_ matcher: RoadObjectMatcher, didCancelMatchingFor id: String) {
        return
    }
}

extension Tracker {
    @objc func didUpdateRoadName(_ notification: Notification) {
        //guard
            //let newLocation = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.locationKey] as? CLLocation,
            //let roadShield = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.routeShieldRepresentationKey] as? MapboxDirections.VisualInstruction.Component.ImageRepresentation,
            //let roadName = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.roadNameKey] as? String
        //else { return }
        
//        print(roadShield.shield.debugDescription)
//        print(roadName)

    }

    @objc func didUpdateLocation(_ notification: Notification) {
        guard
            let newLocation = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.locationKey] as? CLLocation
            //let matches = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.matchesKey] as? [Match],
            //let result = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.mapMatchingResultKey] as? MapMatchingResult
            //let newLocationRaw = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.rawLocationKey] as? CLLocation
        else { return }
//        for match in matches {
//            print("Match: \(match.expectedTravelTime)")
//            print("\(match.legs.first?.name ?? "Unknown")")
//        }
//        print("Enhanced Location: \(result.enhancedLocation.debugDescription)")
//        print("Key points: \(result.keyPoints.debugDescription)")
//        print("Off road: \(result.offRoadProbability.debugDescription)")
//        print("Road edge match: \(result.roadEdgeMatchProbability.debugDescription)")
        
        if queryAllLayersIsReady && UserDefaults.standard.bool(forKey: "track_localities_master_switch") && (lastLocationSentToQueryingLayers == nil || lastLocationSentToQueryingLayers?.distance(from: newLocation) ?? UserDefaults.standard.double(forKey: "distance_update_sensitivity_value")+1 >= UserDefaults.standard.double(forKey: "distance_update_sensitivity_value")) {

            queryLayers(newLocation, trackingLayers) // TODO: do i want to wrap this in a "test" if-then section, to allow the test cases to control when this is called?
            lastLocationSentToQueryingLayers = newLocation
            delegate?.queryingLayers() // TODO: pass location to this delegate?
            //print("Speed: \((newLocation.speed * 60 * 60)/1609)")
            
//            let currentLoc = CLLocation(coordinate: newLocation.coordinate, altitude: newLocation.altitude, horizontalAccuracy: newLocation.horizontalAccuracy, verticalAccuracy: newLocation.verticalAccuracy, course: newLocation.course, speed: 60, timestamp: newLocation.timestamp)
//            passiveLocationManager.updateLocation(currentLoc)
            
            return
        }
        delegate?.failedToGetLocationUpdate()
    }
}

extension Tracker {
    func queryLayers(_ loc: CLLocation, _ layers: [TrackingLayer]) {
        queryAllLayersIsReady = false
        
        self.queryQueue.async {
            var localityReports: [LocalityReport] = []
            for layer in self.trackingLayers {
                self.queryGroup.enter()
                
                var callNetwork = false
                if layer.doINeedToCallNetwork(loc) {
                    self.delegate?.needsToCallNetwork()
                    callNetwork = true
                }
                
                self.layerProcessingQueue.async(group: self.queryGroup, qos: .userInteractive, flags: .assignCurrentContext) {
                                        
                    layer.queryNewProximities(loc, callNetwork, self.passiveLocationManager, self.lastKnownEHPHorizon, self.lastKnownEHPDistances) { report, network in
                        
                        if network == true {
                            self.delegate?.networkReturnedWithData()
                        }
                        if let report = report {
                            if network || (!report.approachingAlerts.isEmpty || !report.enteredLocalities.isEmpty || !report.exitedLocalities.isEmpty) || UserDefaults.standard.object(forKey: "\(report.layer.name) layer") == nil {
                                do {
                                    let encoder = JSONEncoder()
                                    let item = try encoder.encode(report.layer)
                                    UserDefaults.standard.set(item, forKey: "\(layer.name) layer")
                                } catch {
                                    print("Unable to encode \(error)")
                                }
                            }
                            
                            if !(report.enteredLocalities.isEmpty && report.exitedLocalities.isEmpty && report.currentLocalities.isEmpty && report.approachingAlerts.isEmpty && report.neighboringLocalities.isEmpty) {
                                localityReports.append(report) // TODO: bring this array inside this function. // TODO: THIS HAS A BAD ACCESS PROBLEM
                                //print("Received and appending \(localityReports.count) to localityReports from \(layer.name)")
                            } else {
                                print("Received report from \(layer.name) but it was empty, so not appending.")
                            }
                        } else {
                            print("\n\nThe \(layer.name) layer did not succesfully pull in a new locality layer update.")
                        }
                        self.queryGroup.leave()
                    }
                }
            }
                
            self.queryGroup.notify(queue: .main) {
                if UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
                    localityReports.reverse()
                    // TODO: the reverse thing doesnt work because the localities all get back at different times
                    self.processLocalityReports(localityReports) // TODO: seperate this from being inside here
                    self.delegate?.trackerHasNewLocalityReports(self, localityReports: localityReports, self.passiveLocationManager, self.lastKnownEHPHorizon, self.lastKnownEHPDistances)
                }
                self.queryAllLayersIsReady = true
            }
        }
    }

    // TODO: move this into map view controller, probably
    func processLocalityReports(_ localityReports: [LocalityReport]) {
        if localityReports.isEmpty {
            return
        }
        
        // TODO: dequeue the locality reports? currently doing an ugly remove all
        
        // Get the current road name
        var finalRoadName = ""
        var currentRoadCode = ""
        var currentRoadName = ""
        if let id = lastKnownEHPPosition?.edgeIdentifier {
            if let currentEdge = passiveLocationManager.roadGraph.edgeMetadata(edgeIdentifier: id) {
                for name in currentEdge.names {
                    switch name {
                    case .name(let name):
                        if currentRoadName == "" {
                            currentRoadName = name
                        }
                        //print("Road name: \(name)")
                    case .code(let code):
                        if currentRoadName == "" {
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
        }
    
        // MARK: Text Notifications
        var textPushNotifications = [String]()

        for report in localityReports {
            var newFeatures: [Turf.Feature] = []

            for locality in report.enteredLocalities {
                if finalRoadName != "" {
                    textPushNotifications.append("Entering \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2)) on \(finalRoadName).")
                } else {
                    textPushNotifications.append("Entering \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2))")
                }

                newFeatures.append(locality.info.geojson)
            }
            
            for locality in report.exitedLocalities {
                if report.enteredLocalities.isEmpty && finalRoadName != "" {
                    textPushNotifications.append("Leaving \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2)) on \(finalRoadName).")
                } else {
                    textPushNotifications.append("Leaving \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2)).")
                }
            }
            
            for alert in report.approachingAlerts {
                textPushNotifications.append(HelperFunctions.GetProximityString(alert))
                if UserDefaults.standard.bool(forKey: "announce_one_alert_at_a_time") {
                    break
                }
            }
            
            if report.layer.name == "us_military_bases" {
                if !report.neighboringLocalities.isEmpty {
                    for neighbor in report.neighboringLocalities {
                        if (neighbor.directDistance! < 600) {
                            passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 400, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 2))
                            break
                        } else {
                            passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: nil))
                        }
                    }
                } else {
                    passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: nil))
                }
                
                if !report.currentLocalities.isEmpty {
                    passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 400, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 2))
                }
            }
        }
        
        // MARK: say the entering voice notifications
        let enteringNotifications = HelperFunctions.constructEnteringString(localityReports: localityReports)
        if enteringNotifications != "" {
            self.screecher.play(enteredstring: enteringNotifications, alert: true, interupt: true)
        }
        
        // MARK: say the exiting voice notifications
        let exitingNotifications = HelperFunctions.constructExitingString(localityReports: localityReports)
        if exitingNotifications != "" && (!UserDefaults.standard.bool(forKey: "use_simple_alerts") || (UserDefaults.standard.bool(forKey: "use_simple_alerts") && enteringNotifications == "" ))  {
            self.screecher.play(enteredstring: exitingNotifications, alert: false, interupt: enteringNotifications.isEmpty)
        }
        
        // MARK: say the approaching voice notifications
        let combinedVoiceString = HelperFunctions.constructApproachingString(localityReports: localityReports)
        if combinedVoiceString != "" && !UserDefaults.standard.bool(forKey: "use_simple_alerts") {
            self.screecher.play(enteredstring: combinedVoiceString, alert: false)
        }
        
        // MARK: Process notification string from reports above
        var answer = ""
        while !textPushNotifications.isEmpty {
            answer.append(textPushNotifications.removeFirst())
            if !textPushNotifications.isEmpty {
                answer.append("\n")
            }
        }

        if answer != "" {
            self.notifier.sendNotification(title: "", body: answer)
        }
    }
}
