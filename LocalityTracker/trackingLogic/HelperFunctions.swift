//
//  HelperFunctions.swift
//  testingground
//
//  Created by Jack Bowden on 7/8/21.
//

import Foundation
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import Turf
import CoreLocation

class HelperFunctions {
    
    static func constructEnteringString(localityReports: [LocalityReport]) -> String {
        var decompEnters = localityReports.flatMap { $0.enteredLocalities }
        
        for enteredZipPlaces in decompEnters.filter({AR in AR.layername == "us_zip_places"}) {
            if decompEnters.filter({AR in AR.layername != "us_zip_places"}).contains(where: { AR2 in AR2.info.name == enteredZipPlaces.info.name }) {
                decompEnters.removeAll(where: {AR in AR == enteredZipPlaces})
            }
        }

        var enteringNotifications = ""
        for locality in decompEnters {
            if locality.layername == "us_zip_places" && decompEnters.firstIndex(where: { otherLocality in
                otherLocality.info.name == locality.info.name && otherLocality.layername != "us_zip_places"
            }) != nil {
                continue
            }

            if locality == decompEnters.first || enteringNotifications.isEmpty {
                var enteringText = "Entering "
                if UserDefaults.standard.bool(forKey: "use_simple_alerts") {
                    enteringText = ""
                }
                enteringNotifications += "\(enteringText)\(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2, vocal: true))"
                if locality == decompEnters.last && decompEnters.count == 1 {
                    enteringNotifications += "."
                    continue
                }
            } else if locality != decompEnters.first && locality != decompEnters.last {
                enteringNotifications += ", \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2, vocal: true))"
            } else if locality == decompEnters.last && decompEnters.count > 1 {
                enteringNotifications += " and \(HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2, vocal: true))."
            }
        }
        
        return enteringNotifications
    }
    
    static func constructExitingString(localityReports: [LocalityReport]) -> String {
        var decompExits = localityReports.flatMap { $0.exitedLocalities }
        
        for exitedZipPlaces in decompExits.filter({AR in AR.layername == "us_zip_places"}) {
            if decompExits.filter({AR in AR.layername != "us_zip_places"}).contains(where: { AR2 in AR2.info.name == exitedZipPlaces.info.name }) {
                decompExits.removeAll(where: {AR in AR == exitedZipPlaces})
            }
        }
        
        var exitingNotifications = ""
        for locality in decompExits {
            if locality.layername == "us_zip_places" && decompExits.firstIndex(where: { locality2 in
                locality2.info.name == locality.info.name && locality2.layername != "us_zip_places"
            }) != nil {
                continue
            }

            var endName = HelperFunctions.decideOrganizingOrder(localityInfo: locality.info, order: 2, vocal: true)
            if locality.layername == "us_military_bases" {
                endName = "federal jurisdiction"
            }
            if locality == decompExits.first || exitingNotifications.isEmpty {
                exitingNotifications += "Leaving \(endName)"
                if locality == decompExits.last && decompExits.count == 1 {
                    exitingNotifications += "."
                }
            } else if locality != decompExits.last {
                exitingNotifications += ", \(endName)"
            } else if locality == decompExits.last && decompExits.count > 1 {
                exitingNotifications += " and \(endName)."
            }
        }
        
        return exitingNotifications
    }
    
    static func constructApproachingString(localityReports: [LocalityReport]) -> String {
        var decompApproaches = localityReports.flatMap { $0.approachingAlerts }
        
        if UserDefaults.standard.bool(forKey: "announce_one_alert_at_a_time") {
            decompApproaches = []
                        
            for report in localityReports {
                for alert in report.approachingAlerts {
                    decompApproaches.append(alert)
                    break
                }
            }
        }

        for zipPlaceApproaches in decompApproaches.filter({AR in AR.alertingFeature.layername == "us_zip_places"}) {
            if decompApproaches.filter({AR in AR.alertingFeature.layername != "us_zip_places"}).contains(where: { AR2 in AR2.alertingFeature.info.name == zipPlaceApproaches.alertingFeature.info.name }) {
                decompApproaches.removeAll(where: {AR in AR == zipPlaceApproaches})
            }
        }
        
        var combinedApproachingVoiceString = ""
        
        var alertTypesUnderConsideration = decompApproaches.filter({ alert in
            alert.alertType == .oneFourthAMile
        })

        for alert in alertTypesUnderConsideration {
            if alert == alertTypesUnderConsideration.first || combinedApproachingVoiceString.isEmpty {
                combinedApproachingVoiceString += "Approaching \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            } else if alert != alertTypesUnderConsideration.first && alert != alertTypesUnderConsideration.last {
                combinedApproachingVoiceString += ", \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            }
            
            if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count > 1 {
                combinedApproachingVoiceString += " and \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true)). Boundary crossing imminent! "
            } else if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count == 1 {
                combinedApproachingVoiceString += ". Boundary crossing imminent! "
            }
        }
        
        alertTypesUnderConsideration = decompApproaches.filter({ alert in
            alert.alertType == .halfAMile
        })
        
        for alert in alertTypesUnderConsideration {
            if alert == alertTypesUnderConsideration.first || combinedApproachingVoiceString.isEmpty {
                combinedApproachingVoiceString += "Approaching \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            } else if alert != alertTypesUnderConsideration.first && alert != alertTypesUnderConsideration.last {
                combinedApproachingVoiceString += ", \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            }
            
            if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count > 1 {
                combinedApproachingVoiceString += " and \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true)). Distance: half a mile. "
            } else if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count == 1 {
                combinedApproachingVoiceString += ". Distance: half a mile. "
            }
        }
        
        alertTypesUnderConsideration = decompApproaches.filter({ alert in
            alert.alertType == .oneMile
        })
        
        for alert in alertTypesUnderConsideration {
            if alert == alertTypesUnderConsideration.first || combinedApproachingVoiceString.isEmpty {
                combinedApproachingVoiceString += "Approaching \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            } else if alert != alertTypesUnderConsideration.first && alert != alertTypesUnderConsideration.last {
                combinedApproachingVoiceString += ", \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            }
            
            if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count > 1 {
                combinedApproachingVoiceString += " and \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true)). Distance: one mile. "
            } else if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count == 1 {
                combinedApproachingVoiceString += ". Distance: one mile. "
            }
        }
        
        alertTypesUnderConsideration = decompApproaches.filter({ alert in
            alert.alertType == .twoMiles
        })
        
        for alert in alertTypesUnderConsideration {
            if alert == alertTypesUnderConsideration.first || combinedApproachingVoiceString.isEmpty {
                combinedApproachingVoiceString += "Approaching \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            } else if alert != alertTypesUnderConsideration.first && alert != alertTypesUnderConsideration.last {
                combinedApproachingVoiceString += ", \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true))"
            }
            
            if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count > 1 {
                combinedApproachingVoiceString += " and \(HelperFunctions.decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: true)). Distance: two miles. "
            } else if alert == alertTypesUnderConsideration.last && alertTypesUnderConsideration.count == 1 {
                combinedApproachingVoiceString += ". Distance: two miles. "
            }
        }
        
        return combinedApproachingVoiceString
    }
    
    static func findEdgeIntersectionWithLocality(_ passiveLocationManager: PassiveLocationManager, _ edge: RoadGraph.Edge, _ locality: LayerAPIResponse.Locality.Info, _ intersectingPointsToIgnore: [LocationCoordinate2D]?, lineStrings: [LineString]? = []) -> IntEdge? {
            
        //guard let edgeLineString: LineString = passiveLocationManager.roadGraph.edgeShape(edgeIdentifier: edge.identifier) else { return nil }
        
        guard let edgeLineStringOld: LineString = passiveLocationManager.roadGraph.edgeShape(edgeIdentifier: edge.identifier) else { return nil }
        
        var edgeLineString = edgeLineStringOld
        if lineStrings == [] {
            edgeLineString = edgeLineStringOld.sliced(from: passiveLocationManager.location?.coordinate, to: edgeLineStringOld.coordinates.last)!
        }
        
        if case let .multiPolygon(multipolygon) = locality.geojson.geometry {
            for polygon in multipolygon.polygons {
                for ring in polygon.coordinates {
                    let intersections = LineString(ring).intersections(with: edgeLineString)
                    // TODO: dont warn about intersections that run down the middle of the road?
                    if let answer = intersections.first(where: { coord in
                        !(intersectingPointsToIgnore?.contains(coord) ?? false)
                    }) {
                        var totalLength = 0.0
                        for line in lineStrings! {
                            totalLength += line.distance()!
                        }
                        return IntEdge(intersectionPoint: answer, roadEdge: edge, polylineToIntersection: edgeLineString.sliced(from: edgeLineString.coordinates.first!, to: answer)!, locality: locality, distance: totalLength + (edgeLineString.sliced(from: edgeLineString.coordinates.first, to: answer)?.distance())!)
                    }
                }
                
            }
        }
        if !edge.outletEdges.isEmpty {
            for nextEdge in edge.outletEdges {
                var newOne: [LineString] = []
                newOne.append(contentsOf: lineStrings!)
                newOne.append(edgeLineString)
                return findEdgeIntersectionWithLocality(passiveLocationManager, nextEdge, locality, intersectingPointsToIgnore, lineStrings: newOne)
            }
        }
        return nil
    }

    
//    static func findEdgeIntersectionWithLocality(_ passiveLocationManager: PassiveLocationManager, _ edge: RoadGraph.Edge, _ locality: LayerAPIResponse.Locality.Info) -> [IntEdge]? {
//
//        var gotit: [IntEdge] = []
//
//        var edges: [RoadGraph.Edge] = []
//
//        edges.append(edge)
//        var pointedEdge = edge
//        while !pointedEdge.outletEdges.isEmpty {
//            for nextEdge in pointedEdge.outletEdges {
//                edges.append(nextEdge)
//                pointedEdge = nextEdge
//            }
//        }
//
//        for edge in edges {
//            guard let edgeLineString: LineString = passiveLocationManager.roadGraph.edgeShape(edgeIdentifier: edge.identifier) else { return nil }
//
//            if case let .multiPolygon(multipolygon) = locality.geojson.geometry {
//                for polygon in multipolygon.polygons {
//                    for ring in polygon.coordinates {
//                        let intersections = LineString(ring).intersections(with: edgeLineString)
//                        for intersection in intersections {
//                            gotit.append(IntEdge(intersectionPoint: intersection, roadEdge: edge, polylineToIntersection: edgeLineString.sliced(from: edgeLineString.coordinates.first!, to: intersection)!, locality: locality))
//                        }
//                    }
//                }
//            }
//        }
//
//        return gotit
//    }
    
    struct IntEdge {
        let intersectionPoint: LocationCoordinate2D
        let roadEdge: RoadGraph.Edge
        let polylineToIntersection: LineString
        let locality: LayerAPIResponse.Locality.Info
        let distance: Double
    }
    
    static func GetProximityString(_ alert: TrackingFeature.AlertReport, vocal: Bool? = false) -> String {
        
        switch alert.alertType {
        case .oneFourthAMile:
            if alert.finalRoadName != "" {
                return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Location: \(alert.finalRoadName ?? "unknown"), boundary crossing imminent!"
            }
            return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)), boundary crossing imminent!"
        case .halfAMile:
            if alert.finalRoadName != "" {
                return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Location: \(alert.finalRoadName ?? "unknown"). Distance: half a mile."
            }
            return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Distance: half a mile."
        case .oneMile:
            if alert.finalRoadName != "" {
                return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Location: \(alert.finalRoadName ?? "unknown"). Distance: One mile."
            }
            return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Distance: One mile."
        case .twoMiles:
            if alert.finalRoadName != "" {
                return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Location: \(alert.finalRoadName ?? "unknown"). Distance: Two miles."
            }
            return "Approaching \(decideOrganizingOrder(localityInfo: alert.alertingFeature.info, order: 2, vocal: vocal)). Distance: Two miles."
        }
    }

    static func decideOrganizingOrder(localityInfo: LayerAPIResponse.Locality.Info, order: Int? = 2, vocal: Bool? = false) -> String {
        enum requestType {
            case vocal, label
        }
        
        enum preferredOrder {
            case NameType, theTypeofName, TypeofName
        }
        
        // todo: get a better idea than this
        if localityInfo.name.lowercased() == "district of columbia" {
            return "the \(localityInfo.name)"
        }
        
        switch localityInfo.type?.lowercased() {
        case "city", "town", "commonwealth", "state":
            if vocal! {
                return "the \(localityInfo.type ?? "") of \(localityInfo.name)"
            } else {
                return "\(localityInfo.type ?? "") of \(localityInfo.name)"
            }
        case "vicinity", "village", nil:
            return "\(localityInfo.name)"
        case "cdp":
            if vocal! {
                return "\(localityInfo.name) proper"
            } else {
                return "\(localityInfo.name)"
            }
        case "county", "parish", "borough", "area":
            return "\(localityInfo.name) \(localityInfo.type ?? "")"
        default:
            if order == 1 {
                // York County
                return "\(localityInfo.name ) \(localityInfo.type ?? "")"
            } else if order == 2 {
                // the County of York
                return "the \(localityInfo.type ?? "") of \(localityInfo.name )"
            } else {
                // County of York
                return "\(localityInfo.type ?? "") of \(localityInfo.name )"
            }
        }
    }
}
