//
//  MapViewController+StyleButton.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 01/13/22.
//

import Foundation
import UIKit

extension MapViewController {

    func loadStyleButton() {

        // Create a UISegmentedControl to toggle between map styles
        styleToggle = UISegmentedControl(items: ["Locality At-Large", "Two Mile Horizon"])
        styleToggle?.translatesAutoresizingMaskIntoConstraints = false
        styleToggle?.tintColor = UIColor(red: 0.976, green: 0.843, blue: 0.831, alpha: 1)
        styleToggle?.backgroundColor = UIColor(red: 0.973, green: 0.329, blue: 0.294, alpha: 1)
        styleToggle?.layer.cornerRadius = 4
        styleToggle?.clipsToBounds = true
        styleToggle?.selectedSegmentIndex = 0
        styleToggle?.isHidden = !UserDefaults.standard.bool(forKey: "track_localities_master_switch")
        styleToggle?.addTarget(self, action: #selector(changeStyle(sender:)), for: .valueChanged)
        mapView.addSubview(styleToggle!)

        // Configure autolayout constraints for the UISegmentedControl to align
        // at the bottom of the map view and above the Mapbox logo and attribution
        NSLayoutConstraint.activate([NSLayoutConstraint(item: styleToggle as Any, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: mapView, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0)])
        NSLayoutConstraint.activate([NSLayoutConstraint(item: styleToggle as Any, attribute: .bottom, relatedBy: .equal, toItem: mapView, attribute: .bottom, multiplier: 1, constant: -30)]) //-80
    }

    // Change the map style based on the selected index of the UISegmentedControl
    @objc func changeStyle(sender: UISegmentedControl) {
        //if let currentLastLayer = trackingLayers.last {
        
        switch sender.selectedSegmentIndex {
        case 1:
            print("Closest Boundary Mode")
            setCameraOnElectronicHorizonLine()
        default:
            print("At-Large Mode")
            if currentDisplayLayer == "all" {
                // todo: //paintBoundaryLineOnly(lastLocalityReportsReceived.first(where: {lR in lR.layer.name == currentDisplayLayer})!, rest: lastLocalityReportsReceived)
                setCameraOnWholeOfAllCurrentLocalitiesInLocalityReport(lastLocalityReportsReceived)
                // todo: need to implement label for all
                // todo: need to implement logo for all
            } else {
                if let targetDisplayLocality = lastLocalityReportsReceived.first(where: {lR in
                    lR.layer.name == currentDisplayLayer
                }) {
                    if !UserDefaults.standard.bool(forKey: "show_all_lines") {
                        paintBoundaryLineOnly(toPaint: [targetDisplayLocality], toEnsureUnpainted: lastLocalityReportsReceived)
                    } else {
                        paintBoundaryLines(lastLocalityReportsReceived)
                    }
                    paintBoundaryLines([targetDisplayLocality])
                    setCurrentLocalityLabel(targetDisplayLocality)
                    setCameraOnWholeOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
                    displayLogoOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
                }
            }
        }
    }
}
