//
//  TrackingLayer.swift
//  LocalityTracker
//
//  Created by Jack Bowden on 6/29/21.
//

import Foundation
import CoreLocation
import Turf
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

private let concurrentTrackingFeaturesQueue = DispatchQueue(label: "me.jackbowden.LocalityTrackerNav.trackingfeaturesqueue", attributes: .concurrent)
var session: URLSession = URLSession(configuration: URLSessionConfiguration.default)

// todo: consider making this a struct too
final class TrackingLayer: Equatable, Codable {
    // todo: dont let anything in here be public by default because we want to protect the feature class
    // from being accessed by reference -- in case we're looping through it
    
    private var originLatitude: Double = 0.0
    private var originLongtitude: Double = 0.0
    private var originHorizontalAccuracy: Double = 0.0
    private var originDate: Date = Date()
    private(set) public var originLocation: CLLocation {
        get {
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongtitude), altitude: 0, horizontalAccuracy: originHorizontalAccuracy, verticalAccuracy: 0, timestamp: originDate)
        }
        set {
            originLatitude = newValue.coordinate.latitude
            originLongtitude = newValue.coordinate.longitude
            originHorizontalAccuracy = newValue.horizontalAccuracy
            originDate = newValue.timestamp
        }
    }
    private(set) public var time: String
    private(set) public var range: Double
    let name: String
    var roads: Bool = false
    
    private var latitude: Double = 0.0
    private var longtitude: Double = 0.0
    private var horizontalAccuracy: Double = 0.0
    private var date: Date = Date()
    private(set) public var lastLocationUpdate: CLLocation {
        get {
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longtitude), altitude: 0, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: 0, timestamp: date)
        }
        set {
            latitude = newValue.coordinate.latitude
            longtitude = newValue.coordinate.longitude
            horizontalAccuracy = newValue.horizontalAccuracy
            date = newValue.timestamp
        }
    }
    private var _trackingFeatures: [TrackingFeature]? = nil
    
    init(range: Double, name: String, useLocalServer: Bool? = false) {//, loc: CLLocation) {
        self.name = name
        self.time = ""
        self.range = range
    }
    
    var trackingFeatures: [TrackingFeature]? {
        
        var trackingFeaturesCopy: [TrackingFeature]? = nil
        concurrentTrackingFeaturesQueue.sync {
            if self._trackingFeatures != nil {
                trackingFeaturesCopy = self._trackingFeatures!
            }
        }
        return trackingFeaturesCopy
    }
    
    static func == (lhs: TrackingLayer, rhs: TrackingLayer) -> Bool {
        return lhs.name == rhs.name
    }
    
    var roadsEnabled = "no" //yes or no
    func getInfoFromPoint(loc: CLLocationCoordinate2D, completion: @escaping (LayerAPIResponse?) -> ()) {
        // todo: fix this to be an environment var again
        var serverSite = "http://localities.jackbowden.me:5001"
        #if targetEnvironment(simulator)
        serverSite = "http://localhost:5001"
        #endif
        var url: URLRequest = URLRequest(url: URL(string: "\(serverSite)/layer?lat=\(loc.latitude)&long=\(loc.longitude)&layer=\(name)&closest=\(range),30")!, timeoutInterval: 120)
        print("Calling API at \(serverSite) for \(self.name) layer for coordinates \(loc.latitude), \(loc.longitude).")
        url.httpShouldUsePipelining = true
        let task = session.dataTask(with: url, completionHandler: { data, response, error in
            // Check the response
            //print(response)
            
            // Check if an error occured
            if error != nil {
                // HERE you can manage the error
                print("DataTask had an error and did not get new layer, firing delegate call. \(error.debugDescription)")
                completion(nil)
            } else {
                // Serialize the data into an object
                do {
                    //https://app.quicktype.io/
                    let json = try JSONDecoder().decode(LayerAPIResponse.self, from: data!)
                    completion(json)
                } catch {
                    print("Error during JSON serialization: \(error.localizedDescription). Firing delegate call.")
                    completion(nil)
                }
            }
        })
        task.taskDescription = name
        task.resume()
    }
    
    func doINeedToCallNetwork(_ loc: CLLocation) -> Bool { // todo: rework this to return async so we can tell user that network call is in progress and not to wait for it?
        return (loc.distance(from: self.originLocation)/1609.0 > self.range)
    }
    
    func queryNewProximities(_ loc: CLLocation, _ doINeedToCallNetwork: Bool, _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?, completion: @escaping (LocalityReport?, Bool) -> ()) {
        if doINeedToCallNetwork {
            getInfoFromPoint(loc: loc.coordinate) { response in
                if let response = response {
                    print("Response from refreshFeature for \(self.name) is back successfully.")
                    if self._trackingFeatures == nil {
                        self._trackingFeatures = []
                    }
                    
                    var newOne: [TrackingFeature] = []
                    for locality in response.localities {
                        newOne.append(TrackingFeature(layername: self.name, locality: locality, alertStartLocation: CLLocation(latitude: response.lat, longitude: response.long)))
                    }
                    
                    let difference = newOne.difference(from: self._trackingFeatures!)
                    var localitiesWeAreInside: [TrackingFeature] = []
                    for update in difference {
                        switch update {
                        case .remove( _, let letter, _):
                            if letter.isInside {
                                localitiesWeAreInside.append(letter)
                            } else {
                                print("Removing \(letter.info.name)")
                            }
                        case .insert( _, let letter, _):
                            print("Inserting \(letter.info.name)")
                            if !letter.info.isInside(self.lastLocationUpdate) {
                                letter.isInside = false
                            }
                            // is this fix for the newport news problem? idk
                        }
                    }
                    
                    concurrentTrackingFeaturesQueue.async(flags: .barrier) { [weak self] in
                        guard let self = self else {
                            return
                        }
                        self.originLocation = CLLocation(latitude: response.lat, longitude: response.long)
                        self.time = response.time
                        self.range = response.range
                        self.roads = response.roads
                        self.originDate = Date()
                        
                        self._trackingFeatures = self._trackingFeatures!.applying(difference)!
                        
                        // another fix idea for newport news problem
                        for locality in localitiesWeAreInside {
                            if ((self._trackingFeatures?.contains(where: { feature in
                                feature.info.name == locality.info.name
                            })) == false) {
                                print("Re-adding \(locality.info.name) to feature list.")
                                self._trackingFeatures!.append(locality)
                            }
                        }
                        
                        self.lastLocationUpdate = loc
                        // now notify main async queue that there's a new element in the list
                        
                        completion(self.collectLocalityReport(loc, self._trackingFeatures!, passiveLocationManager, horizon, distances), true)
                    }
                } else {
                    print("Response from refreshFeature for \(self.name) is back with errors.")
                    completion(nil, true)
                }
            }
        } else {
            let localityReport = self.collectLocalityReport(loc, self.trackingFeatures ?? [TrackingFeature](), passiveLocationManager, horizon, distances)
            self.lastLocationUpdate = loc
            completion(localityReport, false)
        }
    }
    
    func queryCurrentProximities() -> LocalityReport? {
        if let trackingFeatures = trackingFeatures {
            var localityReport = LocalityReport(layer: self, latitude: lastLocationUpdate.coordinate.latitude, longitude: lastLocationUpdate.coordinate.longitude)
            for feature in trackingFeatures {
                switch feature.isInside {
                case true:
                    localityReport.currentLocalities.append(feature)
                case false:
                    localityReport.neighboringLocalities.append(feature)
                }
            }
            return localityReport
        }
        return nil
    }
    
    
    func collectLocalityReport(_ loc: CLLocation, _ trackingFeatures: [TrackingFeature], _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?) -> LocalityReport {
        
        var localityReport = LocalityReport(layer: self, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        for feature in trackingFeatures {
            let collectedTrackingUpdate = feature.newTrackingLocation(loc, passiveLocationManager, horizon)
            switch collectedTrackingUpdate.status {
            case .hasEntered:
                localityReport.enteredLocalities.append(feature) //consider only appending feature info
                localityReport.currentLocalities.append(feature)
            case .hasLeft:
                localityReport.exitedLocalities.append(feature)
                localityReport.neighboringLocalities.append(feature)
                //feature.neuter()
            case .stillInside:
                localityReport.currentLocalities.append(feature)
            case .stillOutside:
                localityReport.neighboringLocalities.append(feature)
            
            if let alert = collectedTrackingUpdate.alert {
                localityReport.approachingAlerts.append(alert)
            }
                
            // todo: implement this 
            //CLCircularRegion.init(center: loc.coordinate, radius: (feature.alerter?.setDistances.last!.rawValue)!, identifier: "\(feature.info.gid)")
            //}
            }
        }
    
        localityReport.approachingAlerts.sort { first, second in
            (first.alertingFeature.closestRoadCrossingDistance ?? first.alertingFeature.directDistance)! < (second.alertingFeature.closestRoadCrossingDistance ?? second.alertingFeature.directDistance)!
        }
        
        localityReport.neighboringLocalities.sort { first, second in
            (first.closestRoadCrossingDistance ?? first.directDistance)! < (second.closestRoadCrossingDistance ?? second.directDistance)!
        }
        return localityReport
    }
}
