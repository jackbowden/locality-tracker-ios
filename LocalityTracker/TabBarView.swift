//
//  TabBarView.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/9/22.
//

import Foundation
import UIKit
import InAppSettingsKit
class TabBarView: UITabBarController, UITabBarControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Assign self for delegate for that ViewController can respond to UITabBarControllerDelegate methods
        self.delegate = self
        
        //UITabBar.appearance().barTintColor = UIColor(named: "barBackground")
        
        //self.tabBar.tintColor = .systemBackground
        self.updateBarTintColor()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create Tab one
        let tabOne = MapViewController()
        let tabOneBarItem = UITabBarItem(title: "Map", image: .strokedCheckmark, tag: .bitWidth)
        
        tabOne.tabBarItem = tabOneBarItem
        
        let appSettingsViewController = IASKAppSettingsViewController()
        let tabTwoBarItem = UITabBarItem(title: "Settings", image: .strokedCheckmark, tag: .bitWidth)
        appSettingsViewController.tabBarItem = tabTwoBarItem
        //navigationController.pushViewController(appSettingsViewController, animated: true)
        
        
        // Create Tab two
//        let tabTwo = MapViewController()
//        let tabTwoBarItem = UITabBarItem(title: "Map3", image: .strokedCheckmark, tag: .bitWidth)
//
//        tabTwo.tabBarItem = tabTwoBarItem
        
        
        self.viewControllers = [tabOne, appSettingsViewController]
    }
    
    // UITabBarControllerDelegate method
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        print("Selected \(viewController.title!)")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateBarTintColor()
    }
    
    private func updateBarTintColor() {
           if #available(iOS 13.0, *) {
               self.tabBar.backgroundColor = UITraitCollection.current.userInterfaceStyle == .dark ? .black : .white
      }
    }
}
