//
//  MapViewController+CurrentLocalityLabel.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/4/22.
//

import Foundation
import UIKit

extension MapViewController {

    func loadCurrentLocalityLabel() {
        currentLocalityLabel = UILabel()
        //CGRect(x: 15, y: 655, width: 150, height: 150)
        currentLocalityLabel?.frame = CGRect(x: 0, y: 100, width: 300, height: 30) //y 100 //y 855
        currentLocalityLabel?.frame.origin.y = (self.mapView.frame.height) - (currentLocalityLabel!.frame.height * 6.25) //4 //5
        currentLocalityLabel?.center.x = view.center.x
        currentLocalityLabel?.textColor = .white
        currentLocalityLabel?.textAlignment = .center
        currentLocalityLabel?.backgroundColor = UIColor(red: 0.973, green: 0.329, blue: 0.294, alpha: 1)
        currentLocalityLabel?.tintColor = UIColor(red: 0.976, green: 0.843, blue: 0.831, alpha: 1)
        currentLocalityLabel?.layer.cornerRadius = 8
        currentLocalityLabel?.layer.masksToBounds = true
        if UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
            if UserDefaults.standard.bool(forKey: "demo_mode") {
                currentLocalityLabel?.text = "Tap to begin."
            } else {
                currentLocalityLabel?.text = "Waiting for Locality"
            }
        } else {
            currentLocalityLabel?.text = "Tracker Off. Enable in settings."
        }
        mapView.addSubview(currentLocalityLabel!)
    }
}
