//
//  CurrentRoadNameLabel.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/12/22.
//

import Foundation
import UIKit

extension MapViewController {

    func loadCurrentRoadNameLabel() {
        currentRoadNameLabel = UILabel()
        //CGRect(x: 15, y: 655, width: 150, height: 150)
        currentRoadNameLabel?.frame = CGRect(x: 80, y: 70, width: 230, height: 30) //y 100 //y 855
        //(x: 25, y: 65, width: 50, height: 40)
        //currentRoadNameLabel?.frame.origin.y = (self.mapView.frame.height) - (currentRoadNameLabel!.frame.height * 6.25) //4 //5
        //currentRoadNameLabel?.center.x = view.center.x
        currentRoadNameLabel?.textColor = .white
        currentRoadNameLabel?.textAlignment = .center
        currentRoadNameLabel?.backgroundColor = UIColor(red: 0.973, green: 0.329, blue: 0.294, alpha: 1)
        currentRoadNameLabel?.tintColor = UIColor(red: 0.976, green: 0.843, blue: 0.831, alpha: 1)
        currentRoadNameLabel?.layer.cornerRadius = 8
        currentRoadNameLabel?.layer.masksToBounds = true
        currentRoadNameLabel?.text = "Waiting for road name."
        if !UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
            currentRoadNameLabel?.isHidden = true
        }
        mapView.addSubview(currentRoadNameLabel!)
    }
}
