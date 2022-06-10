//
//  MapViewController+PaintAndCamera.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/9/22.
//

import Foundation
import UIKit
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import Turf
import CoreLocation

extension MapViewController {
    func paintLines(_ passiveLocationManager: PassiveLocationManager, _ edge: RoadGraph.Edge, _ int: Int? = 0, _ lineStrings: [LineString]? = []) {
        guard
            let edgeLineString = passiveLocationManager.roadGraph.edgeShape(edgeIdentifier: edge.identifier) else {
            //let edgeMetadata = passiveLocationManager.roadGraph.edgeMetadata(edgeIdentifier: edge.identifier) else {
            return
        }// todo: this throws nil, need to guard against that
        
        
        var edgeLineString2 = edgeLineString
        
        // todo: edgeLineString.coordinateFromStart(distance: <#T##LocationDistance#>) for measuring distance to locality crossing
        
        if lineStrings == [] {
            edgeLineString2 = edgeLineString.sliced(from: passiveLocationManager.location?.coordinate, to: edgeLineString.coordinates.last)!
        }
                
        var lineAnt = PolylineAnnotation(lineCoordinates: edgeLineString2.coordinates)
        if edge.level == 0 {
            lineAnt.lineColor = StyleColor(UIColor.red)
            lineAnt.lineWidth = 10
        } else if edge.level == 1 {
            lineAnt.lineColor = StyleColor(UIColor.yellow)
            lineAnt.lineWidth = 7
        } else {
            lineAnt.lineColor = StyleColor(UIColor.green)
            lineAnt.lineWidth = 5
        }
        electronicHorizionLineMarkers.append(lineAnt)
    
        // todo: see if this is a working idea
        for coord in edgeLineString.coordinates {
            if !coordBank.contains(coord) {
                coordBank.append(coord)
            }
        }
        //coordBank.append(contentsOf: edgeLineString.coordinates)
        
        // MARK: this is the one i like
        for lowerEdge in edge.outletEdges {
            var newOne: [LineString] = []
            newOne.append(contentsOf: lineStrings!)
            newOne.append(edgeLineString)
            paintLines(passiveLocationManager, lowerEdge, int!+1, newOne)
        }
        if edge.outletEdges.isEmpty {
            var totalLength = 0.0
            for line in lineStrings! {
                totalLength += line.distance()!
            }
            //print("Edge depth: \(int!). Distance: \(totalLength)")
        }
    }
    
    func setCameraOnWholeLocality(_ feats: [TrackingFeature]) {
        var coordsToFit: [CLLocationCoordinate2D] = []
        for feat in feats {
            if case let .multiPolygon(multipolygon) = feat.info.geojson.geometry  {
                for polygon in multipolygon.polygons {
                    for coordinate in polygon.outerRing.coordinates {
                        coordsToFit.append(coordinate)
                    }
                }
            }
        }
        if !coordsToFit.isEmpty {
            self.mapView.camera.ease(to: mapView.mapboxMap.camera(for: coordsToFit, padding: UIEdgeInsets(top: 120.0, left: 30, bottom: 240.0, right: 30), bearing: nil, pitch: coolPitch), duration: 0)
        }
    }
    
    func setCameraOnWholeOfFirstCurrentLocalityInLocalityReport(_ report: LocalityReport) {
        if let feat = report.currentLocalities.first {
            setCameraOnWholeLocality([feat])
        }
    }
    
    func setCameraOnWholeOfAllCurrentLocalitiesInLocalityReport(_ reports: [LocalityReport]) {
        var feats: [TrackingFeature] = []
        for report in reports {
            feats.append(contentsOf: report.currentLocalities)
        }
        setCameraOnWholeLocality(feats)
    }
    
    func setCameraOnElectronicHorizonLine() {
        var coordsToFit: [CLLocationCoordinate2D] = []
                            
        if !coordBank.isEmpty {
            coordsToFit.append(contentsOf: coordBank)
        }
        if coordsToFit.count >= 2 {
            mapView.camera.ease(to: mapView.mapboxMap.camera(for: coordsToFit, padding: UIEdgeInsets(top: 120.0, left: 100, bottom: 240.0, right: 100), bearing: nil, pitch: coolPitch), duration: 0)
        }
    }
    
    func setCurrentLocalityLabel(_ report: LocalityReport) {
        if !report.currentLocalities.isEmpty {
            self.currentLocalityLabel?.text = "\(HelperFunctions.decideOrganizingOrder(localityInfo: report.currentLocalities[0].info, order: 2))"//" (\(String(format: "%.2f", report.currentLocalities[0].lastKnownDistance/1609))mi)"
        } else if !report.neighboringLocalities.isEmpty && report.currentLocalities.isEmpty {
            self.currentLocalityLabel?.text = "APPR: \(HelperFunctions.decideOrganizingOrder(localityInfo: report.neighboringLocalities[0].info, order: 2))"//" (\(String(format: "%.2f", report.neighboringLocalities[0].lastKnownDistance/1609))mi)"
        } else {
            self.currentLocalityLabel?.text = "I DONT KNOW"
        }
        
        if let currentLineColor = mapView.mapboxMap.style.layerPropertyValue(for: "current line \(report.layer.name)", property: "line-color") as? Array<Any> {
            let currentLineColorConverted = UIColor(red: (currentLineColor[1] as! CGFloat/255), green: (currentLineColor[2] as! CGFloat/255), blue: (currentLineColor[3] as! CGFloat/255), alpha: currentLineColor[4] as! CGFloat)
            if self.currentLocalityLabel!.backgroundColor! != currentLineColorConverted { // todo: make this better
                self.currentLocalityLabel!.backgroundColor = currentLineColorConverted
                self.currentRoadNameLabel!.backgroundColor = currentLineColorConverted
                self.cycleButton.backgroundColor = currentLineColorConverted
                self.styleToggle?.backgroundColor = currentLineColorConverted

                if currentLineColorConverted.isLight {
                    self.currentLocalityLabel?.textColor = UIColor.black
                    self.currentRoadNameLabel?.textColor = UIColor.black
                    let tA = [NSAttributedString.Key.foregroundColor: UIColor.black]
                    self.styleToggle?.setTitleTextAttributes(tA, for: .normal)
                    self.cycleButton.setTitleColor(UIColor.black, for: .normal)
                    
                } else {
                    self.currentLocalityLabel?.textColor = UIColor.white
                    self.currentRoadNameLabel?.textColor = UIColor.white
                    let tA = [NSAttributedString.Key.foregroundColor: UIColor.white]
                    self.styleToggle?.setTitleTextAttributes(tA, for: .normal)
                    self.cycleButton.setTitleColor(UIColor.white, for: .normal)
                }
            }
        }
    }
    
    //todo: refactor this mess, write ui test cases first
    func paintBoundaryLines(_ reports: [LocalityReport]) {
        for report in reports {
            if !report.exitedLocalities.isEmpty {
                if self.mapView.mapboxMap.style.sourceExists(withId: "current shape \(report.layer.name)")  {
                    try? self.mapView.mapboxMap.style.removeLayer(withId: "current line \(report.layer.name)")
                    try? self.mapView.mapboxMap.style.removeSource(withId: "current shape \(report.layer.name)")
                }
            }

            
            if let firstCurrentLocalityInReport = report.currentLocalities.first {
                // if we have no current localities but we have an exited locality,
                // or if we have current localities but no entered localities,
                // then do the following:
                if !self.mapView.mapboxMap.style.sourceExists(withId: "current shape \(report.layer.name)") || (report.currentLocalities.isEmpty && !report.exitedLocalities.isEmpty) || (!report.currentLocalities.isEmpty && !report.enteredLocalities.isEmpty) {
                    if self.mapView.mapboxMap.style.sourceExists(withId: "current shape \(report.layer.name)") {
                        try! self.mapView.mapboxMap.style.updateGeoJSONSource(withId: "current shape \(report.layer.name)", geoJSON: firstCurrentLocalityInReport.info.geojson.geoJSONObject)
                    } else {
                        var mysource: GeoJSONSource = GeoJSONSource()
                        mysource.data = .featureCollection(FeatureCollection(features: [firstCurrentLocalityInReport.info.geojson]))
                        try! self.mapView.mapboxMap.style.addSource(mysource, id: "current shape \(report.layer.name)")
                        
                        var dashedLine = LineLayer(id: "current line \(report.layer.name)")
                        dashedLine.lineColor = .constant(StyleColor(UIColor.random())) // todo: fix random line painting
                        dashedLine.source = "current shape \(report.layer.name)"
                        dashedLine.lineWidth = .constant(7)
                        try! self.mapView.mapboxMap.style.addLayer(dashedLine)
                    }
                }
            }
        }
    }
    
    // note: toPaint will take priority over toEnsureUnpainted
    func paintBoundaryLineOnly(toPaint: [LocalityReport], toEnsureUnpainted: [LocalityReport]) {
        for report in toEnsureUnpainted {
            if toPaint.contains(report) {
                paintBoundaryLines([report])
            } else {
                try? self.mapView.mapboxMap.style.removeLayer(withId: "current line \(report.layer.name)")
                try? self.mapView.mapboxMap.style.removeSource(withId: "current shape \(report.layer.name)")
            }
        }
    }
    
    func removeAllPolylines() {
        let combinedLines: [PolylineAnnotation] = []
        polylineAnnotationManager?.annotations.removeAll()
        polylineAnnotationManager?.annotations.append(contentsOf: combinedLines)
    }
    
//    func removeAllBoundaryLines() {
//        // todo: fix this from not working
////        for layer in tracker.trackingLayers {
////            if self.mapView.mapboxMap.style.layerExists(withId: "current line \(layer.name)") {
////                try? self.mapView.mapboxMap.style.removeLayer(withId: "current line \(layer.name)")
////                if self.mapView.mapboxMap.style.sourceExists(withId: "current shape \(layer.name)") {
////                    try? self.mapView.mapboxMap.style.removeSource(withId: "current shape \(layer.name)")
////                }
////            }
////        }
//        for layer in tracker.trackingLayers {
//            try? self.mapView.mapboxMap.style.removeLayer(withId: "current line \(layer.name)")
//            try? self.mapView.mapboxMap.style.removeSource(withId: "current shape \(layer.name)")
//        }
//    }

    func removeBoundaryLines(_ reports: [LocalityReport]) {
        for report in reports {
            try? self.mapView.mapboxMap.style.removeLayer(withId: "current line \(report.layer.name)")
            try? self.mapView.mapboxMap.style.removeSource(withId: "current shape \(report.layer.name)")
        }
    }
    
    
}
