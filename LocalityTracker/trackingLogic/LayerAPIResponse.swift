//
//  LayerAPIResponse.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/4/22.
//

import Foundation
import CoreLocation
import Turf
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

struct LayerAPIResponse: Codable {
    
    let lat: Double
    let long: Double
    let time: String
    let range: Double
    let name: String
    let roads: Bool
    let localities: [Locality]
    
    struct Locality: Codable {
        
        let info: Info
        let miles: Double
        let isinside: Bool
        
        struct Info: Codable {
            
            let gid: Int
            let name: String
            let type: String?
            var geojson: Turf.Feature
            let sealURL: String?
            let neighbors: [Neighbor]?

            struct Neighbor: Codable {

                let gid: Int
                let name: String
                let type: String?
                let localityports: [LocalityPort]?

                struct LocalityPort: Codable {

                    let name: String?
                    let ref: String?
                    let geojson: Turf.Feature
                }
            }
            
            struct isInsideStruct {
                let answer: Bool
                let isCertain: Bool
                let distance: Double // todo: consider storing closest point on line, closest road port, distances to both, etc
                let closestDirectCoordinate: CLLocationCoordinate2D
            }
            
            func isInside(_ loc: CLLocation, certainty: Bool? = true) -> isInsideStruct {
                var isCertain: Bool = false
                let getDistanceAnswer = getDistance(loc)
                if certainty! && (loc.horizontalAccuracy + 10 < getDistanceAnswer.1 ) { //loc.horizontalAccuracy + 20
                    isCertain = true
                }
                return isInsideStruct(answer: isInside(loc), isCertain: isCertain, distance: getDistanceAnswer.1, closestDirectCoordinate: getDistanceAnswer.0)
            }
            
            func isInside(_ loc: CLLocation) -> Bool {
                if case let .multiPolygon(multipolygon) = geojson.geometry {
                    return multipolygon.contains(loc.coordinate)
                }
                return false
            }
            
            func getClosestPoint(_ loc: CLLocation) -> CLLocationCoordinate2D {
                var answer : CLLocationCoordinate2D? = nil
                if case let .multiPolygon(multipolygon) = geojson.geometry {
//                    let sortedPolygons = multipolygon.polygons.sorted { poly1, poly2 in
//                        poly1.outerRing
//                    }
                    for polygon in multipolygon.polygons {
                        for ring in polygon.coordinates {
                            let candidate = LineString(ring)
                            let calc = candidate.closestCoordinate(to: loc.coordinate)?.coordinate
                            if answer == nil || loc.coordinate.distance(to: CLLocationCoordinate2D(latitude: calc!.latitude, longitude: calc!.longitude)) < loc.coordinate.distance(to: CLLocationCoordinate2D(latitude: answer!.latitude, longitude: answer!.longitude)) {
                                answer = calc
                            }
                        }
                    }
                }
                return answer!
            }
            
            func getDistance(_ loc: CLLocation) -> (CLLocationCoordinate2D, Double) {
                let cP = self.getClosestPoint(loc)
                //let dist = cP.distance(to: loc.coordinate)
                let ugh: CLLocation = CLLocation(latitude: cP.latitude, longitude: cP.longitude)
                let dist = ugh.distance(from: loc)
                return (cP, dist)
            }
        }
    }
}
