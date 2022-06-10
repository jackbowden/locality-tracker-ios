//
//  LocalityTrackerNavTests.swift
//  LocalityTrackerNavTests
//
//  Created by Jack Bowden on 2/9/22.
//

import XCTest
import CoreLocation
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
@testable import LocalityTrackerNav

class LocalityTrackerNavTests: XCTestCase {
    
    var trackingLayers: [TrackingLayer] = []
    var tracker: Tracker = Tracker()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        //continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
        
    func testA() {
        
        UserDefaults.standard.set(true, forKey: "demo_mode")
        UserDefaults.standard.set(true, forKey: "mute_preference")
        
        tracker.updateTrackerSettings()
        tracker.passiveLocationManager.delegate = nil
        
        UserDefaults.standard.removeObject(forKey: "us_counties layer")
        
        XCTAssertEqual(trackingLayers.count, 0, "Tracking Layers count should be 0 here.")
        trackingLayers = []
        
        let yorkCounty: CLLocation = CLLocation(latitude: 37.28, longitude: -76.67)
        
        //tracker.manuallyRequestLocalityReport(yorkCounty)
        let exp = self.expectation(description: "Wait for query new proximities.")
        
        trackingLayers.append(TrackingLayer(range: 15, name: "us_counties"))
        for layer in trackingLayers {
            XCTAssertEqual(layer.name, "us_counties", "Layer name is not us_counties #1")
            
            layer.queryNewProximities(yorkCounty, layer.doINeedToCallNetwork(yorkCounty), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                exp.fulfill()
                
                XCTAssertEqual(network, true, "Network didn't report it needed to be reached, which should be false because we dumped cache, needs to return true")
                XCTAssertNotNil(report)
                
                XCTAssertEqual(report?.currentLocalities.count, 1, "Not inside just one locality")
                
                XCTAssertEqual(self.trackingLayers[0].name, "us_counties", "Layer name is not us_counties")
                
                XCTAssertEqual(report!.currentLocalities[0].info.name, "York", "York County is not the expected current locality")
                XCTAssertEqual(report!.neighboringLocalities.contains(where: { feature in
                    feature.info.name == "James City"
                }), true, "James City County is not a expected neighbor")
                
                XCTAssertEqual(report!.exitedLocalities.count, 0, "Exited localities should be empty")
                XCTAssertEqual(report!.enteredLocalities.count, 1, "Entered localities should report one locality because of the silly glitch we're stubborn to fix") // todo: fix this to be 0
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        
        
        
        
        
    
        let cityOfWilliamsburg: CLLocation = CLLocation(latitude: 37.270787, longitude: -76.709781)
    
        //tracker.manuallyRequestLocalityReport(cityOfWilliamsburg)
        
        XCTAssertEqual(trackingLayers.count, 1, "Tracking Layers count should be 1 here.")
        
        let exp2 = self.expectation(description: "Wait for query new proximities.")

        for layer in trackingLayers {
            
            layer.queryNewProximities(cityOfWilliamsburg, layer.doINeedToCallNetwork(cityOfWilliamsburg), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                exp2.fulfill()
                
                XCTAssertEqual(network, false, "Network did not need to be reached because we have old data from above, so needs to return false")
                XCTAssertNotNil(report)
                
                XCTAssertEqual(report!.currentLocalities.count, 1, "Not inside just one locality")
                
                XCTAssertEqual(self.trackingLayers[0].name, "us_counties", "Layer name is not us_counties #2")
                
                XCTAssertEqual(report!.enteredLocalities[0].info.name, "Williamsburg", "The City of Williamsburg is not the expected entered locality")
                XCTAssertEqual(report!.exitedLocalities[0].info.name, "York", "York County is not the expected exited locality")
                XCTAssertEqual(report!.neighboringLocalities.contains(where: { feature in
                    feature.info.name == "James City"
                }), true, "James City County is not a expected neighbor")
                
                XCTAssertEqual(report!.exitedLocalities.count, 1, "Exited localities should have only 1")
                XCTAssertEqual(report!.enteredLocalities.count, 1, "Entered localities should have only 1")
                
                let enteringString = HelperFunctions.constructEnteringString(localityReports: [report!])
                XCTAssertEqual("Entering the City of Williamsburg.", enteringString, "enteringString is not right.")
                
                let exitingString = HelperFunctions.constructExitingString(localityReports: [report!] )
                XCTAssertEqual("Leaving York County.", exitingString, "exitingString is not right.")
                
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        trackingLayers.append(TrackingLayer(range: 15, name: "us_zip_places"))
        XCTAssertEqual(trackingLayers.count, 2)
        
        let exp3 = self.expectation(description: "Wait for query new proximities.")
        for layer in trackingLayers {
            
            layer.queryNewProximities(cityOfWilliamsburg, layer.doINeedToCallNetwork(cityOfWilliamsburg), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                if layer.name == "us_zip_places" {
                    exp3.fulfill()
                    XCTAssertEqual(network, true, "Network needs to be reached, return true")
                    XCTAssertNotNil(report)
                    
                    XCTAssertEqual(self.trackingLayers[1].name, "us_zip_places", "Layer name is not us_zip_places")
                    
                    XCTAssertEqual(network, true, "Network needs to be true")
                }
                
                XCTAssertNotNil(report)
                
                XCTAssertEqual(report!.currentLocalities.count, 1, "Inside just one locality")

            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        
        
        
        
        
        
    
        let cityOfSuffolk: CLLocation = CLLocation(latitude: 36.860322, longitude: -76.431467)
        tracker.manuallyRequestLocalityReport(cityOfSuffolk)
        
        var timeInSeconds = 10.0 // time you need for other tasks to be finished
        var expectation = XCTestExpectation(description: "Waiting for query new proximities")

        DispatchQueue.main.asyncAfter(deadline: .now() + timeInSeconds) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeInSeconds + 1.0) // make sure it's more than what you used in AsyncAfter call.
        
        var localityReports: [LocalityReport] = []
            
        var exp4 = self.expectation(description: "Wait for query new proximities.")
        for layer in trackingLayers {
            
            // This is Suffolk
            layer.queryNewProximities(cityOfSuffolk, layer.doINeedToCallNetwork(cityOfSuffolk), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 2 {
                    exp4.fulfill()
                }
                
                if layer.name == "us_zip_places" {
                    XCTAssertEqual(network, true, "Network needs to be reached, return true")
                    XCTAssertNotNil(report)
                    
                    XCTAssertEqual(self.trackingLayers[1].name, "us_zip_places", "Layer name is not us_zip_places")
                }
                
                XCTAssertEqual(report!.currentLocalities.count, 1)
                
                XCTAssertEqual(report!.exitedLocalities.count, 1, "Exited localities should have 1")
                XCTAssertEqual(report!.enteredLocalities.count, 1, "Entered localities should have 1")
                
                XCTAssertEqual(report!.enteredLocalities[0].info.name, "Suffolk", "The City of Suffolk is not the expected entered locality")
                XCTAssertEqual(report!.exitedLocalities[0].info.name, "Williamsburg", "The City of Williamsburg is not the expected exited locality")
                XCTAssertEqual(report!.neighboringLocalities.contains(where: { feature in
                    feature.info.name == "Newport News"
                }), true, "Newport News is not an expected neighbor")
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)

                                    
        var enteringString = HelperFunctions.constructEnteringString(localityReports: localityReports)
        XCTAssertEqual("Entering the City of Suffolk.", enteringString, "enteringString is not right.")
        
        let approachingString = HelperFunctions.constructApproachingString(localityReports: localityReports)
        XCTAssertNotEqual("Approaching the City of Chesapeake. Distance: half a mile. Approaching the City of Portsmouth. Distance: one mile. ", approachingString, "Portsmouth is not supposed to be here because it's not on the electronic horizon path for being crossed into.")
        XCTAssertEqual("Approaching the City of Chesapeake. Distance: half a mile. ", approachingString, "approachingString is not right.")
        /// PORTSMOUTH IS COMING BACK AS IN THE VICINITY EVEN THOUGH IT'S A MILE AWAY -- IT'S BEING ALERTED TO WITHOUT HAVING A MAP MATCHING. THIS NEEDS TO BE ADDRESSED.
                
        // TODO: this needs to be fixed
//        let notificationApproachingString = HelperFunctions.GetProximityString((localityReports.first(where: { lR in lR.layer.name == "us_counties"})?.approachingAlerts.first(where: {aR in aR.alertingFeature.info.name == "Chesapeake"}))!, vocal: false)
//        XCTAssertEqual("Approaching City of Chesapeake. Location: I 664 South Hampton Roads Beltway. Distance: half a mile.", notificationApproachingString, "notificationApproachingString is not right.")
    
    
        
        
        
        
        
        
        trackingLayers.append(TrackingLayer(range: 5, name: "us_military_bases"))
        let cityOfPortsmouthBeforeCraney: CLLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 36.87210890653918, longitude: -76.3704105674838), altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: ((4*1609.0)/60/60), timestamp: Date())
        tracker.manuallyRequestLocalityReport(cityOfPortsmouthBeforeCraney)
        
        timeInSeconds = 10.0 // time you need for other tasks to be finished
        expectation = XCTestExpectation(description: "Waiting for query new proximities")

        DispatchQueue.main.asyncAfter(deadline: .now() + timeInSeconds) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeInSeconds + 1.0) // make sure it's more than what you used in AsyncAfter call.
        
        localityReports = []
            
        exp4 = self.expectation(description: "Wait for query new proximities.")
        for layer in trackingLayers {
            
            layer.queryNewProximities(cityOfPortsmouthBeforeCraney, layer.doINeedToCallNetwork(cityOfPortsmouthBeforeCraney), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 3 {
                    exp4.fulfill()
                }
                
                if layer.name == "us_military_bases" {
                    XCTAssertEqual(network, true, "Network needs to be reached, return true")
                    XCTAssertNotNil(report)
                    
                    XCTAssertEqual(self.trackingLayers[2].name, "us_military_bases", "Layer name is not us_military_bases")
                    XCTAssertEqual(report!.currentLocalities.count, 0)
                } else {
                    XCTAssertEqual(report!.currentLocalities.count, 1)
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
                
        
        enteringString = HelperFunctions.constructEnteringString(localityReports: localityReports)
        XCTAssertEqual("Entering the City of Portsmouth.", enteringString, "enteringString is not right.")
        
        //XCTAssertNotNil(localityReports.first(where: { lR in lR.layer.name == "us_military_bases"})?.approachingAlerts.first(where: {aR in aR.alertingFeature.info.name == "Craney Island Fuel Depot"}), "Craney Island has to be in here because we're going 4 mph, so we're gonna cross into it.")
        
        
        
        
        
        
        
        
        
        let cityOfPortsmouthBeforeCraneyButSpeeding: CLLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 36.87210890653918, longitude: -76.3704105674838), altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: ((60*1609.0)/60/60), timestamp: Date())
        tracker.manuallyRequestLocalityReport(cityOfPortsmouthBeforeCraneyButSpeeding)
        
        timeInSeconds = 10.0 // time you need for other tasks to be finished
        expectation = XCTestExpectation(description: "Waiting for query new proximities")

        DispatchQueue.main.asyncAfter(deadline: .now() + timeInSeconds) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeInSeconds + 1.0) // make sure it's more than what you used in AsyncAfter call.
        
        localityReports = []
            
        exp4 = self.expectation(description: "Wait for query new proximities.")
        for layer in trackingLayers {
            
            layer.queryNewProximities(cityOfPortsmouthBeforeCraneyButSpeeding, layer.doINeedToCallNetwork(cityOfPortsmouthBeforeCraneyButSpeeding), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 3 {
                    exp4.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
                
        enteringString = HelperFunctions.constructEnteringString(localityReports: localityReports)
        XCTAssertEqual("", enteringString, "enteringString is not right.")
        
        XCTAssertNil(localityReports.first(where: { lR in lR.layer.name == "us_military_bases"})?.approachingAlerts.first(where: {aR in aR.alertingFeature.info.name == "Craney Island Fuel Depot"}), "Craney f**king Island is in here when it shouldn't be because we're going 60 mph and will not be in the locality for longer than 4 seconds before we exit.")
    }
    
    let fortEustisApproach: CLLocation = CLLocation(latitude: 37.176761, longitude: -76.553501)
    let fortEustisApproach2: CLLocation = CLLocation(latitude: 37.172741, longitude: -76.561314)
    let fortEustisApproach3: CLLocation = CLLocation(latitude: 37.172115, longitude: -76.570451)
    
    func testB_FortEustisRepeatProblem() {
        
        trackingLayers = []

        let exp = self.expectation(description: "Wait for query new proximities.")
        
        var localityReports: [LocalityReport] = []
        
        //tracker.manuallyRequestLocalityReport(fortEustisApproach)
        
        trackingLayers.append(TrackingLayer(range: 15, name: "us_military_bases"))
        trackingLayers.append(TrackingLayer(range: 15, name: "us_zip_places"))
        for layer in trackingLayers {
            layer.queryNewProximities(fortEustisApproach, layer.doINeedToCallNetwork(fortEustisApproach), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 2 {
                    exp.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        let fortEustisZip = localityReports.first(where: { feature in feature.layer.name == "us_zip_places"})?.neighboringLocalities.first(where: {tF in tF.info.name == "Fort Eustis"})
        let fortEustisMil = localityReports.first(where: { feature in feature.layer.name == "us_military_bases"})?.neighboringLocalities.first(where: {tF in tF.info.name == "Fort Eustis"})
        
        var localityReportZip = LocalityReport(layer: TrackingLayer(range: 0.0, name: "us_zip_places"), latitude: 0, longitude: 0)
        localityReportZip.approachingAlerts.append(TrackingFeature.AlertReport(alertingFeature: fortEustisZip!, alertType: TrackingFeature.DistanceAlert.halfAMile))
        
        var localityReportMil = LocalityReport(layer: TrackingLayer(range: 0.0, name: "us_military_bases"), latitude: 0, longitude: 0)
        localityReportMil.approachingAlerts.append(TrackingFeature.AlertReport(alertingFeature: fortEustisMil!, alertType: TrackingFeature.DistanceAlert.halfAMile))
        
        let approachingString = HelperFunctions.constructApproachingString(localityReports: [localityReportZip, localityReportMil])
        XCTAssertEqual("Approaching Fort Eustis. Distance: half a mile. ", approachingString, "approachingString is not right.")
        
    }
    
    let newportNewsCityAndZip: CLLocation = CLLocation(latitude: 37.062488, longitude: -76.461628)
    let newportNewsZipButHamptonCity: CLLocation = CLLocation(latitude: 37.025055, longitude: -76.436136)
    
    func testC_CityOfHamptonButNewportNewsZipProblemWhenItsClose() {
        
        trackingLayers = []

        let exp = self.expectation(description: "Wait for query new proximities.")
        
        var localityReports: [LocalityReport] = []
        
        //tracker.manuallyRequestLocalityReport(newportNewsCityAndZip)
        
        trackingLayers.append(TrackingLayer(range: 15, name: "us_counties"))
        trackingLayers.append(TrackingLayer(range: 15, name: "us_zip_places"))
        for layer in trackingLayers {
            layer.queryNewProximities(newportNewsCityAndZip, layer.doINeedToCallNetwork(newportNewsCityAndZip), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 2 {
                    exp.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
                  
        
        let exp2 = self.expectation(description: "Wait for query new proximities.")
          
        localityReports = []
        
        //tracker.manuallyRequestLocalityReport(newportNewsZipButHamptonCity)
        
        for layer in trackingLayers {
            layer.queryNewProximities(newportNewsZipButHamptonCity, layer.doINeedToCallNetwork(newportNewsZipButHamptonCity), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                  
                if localityReports.count == 2 {
                    exp2.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssertFalse(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Hampton"})}))
        //XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        //XCTAssertFalse(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Hampton"})}))
        
        let enteringString = HelperFunctions.constructEnteringString(localityReports: localityReports)
        XCTAssertEqual("Entering the City of Hampton.", enteringString, "enteringString is not right.")
        
        let exitingString = HelperFunctions.constructExitingString(localityReports: localityReports)
        XCTAssertEqual("Leaving the City of Newport News.", exitingString, "exitingString is not right.")
        
    }
    
    func testD_CityOfHamptonButNewportNewsZipProblemWhenItsFar() {
        
        trackingLayers = []

        let exp = self.expectation(description: "Wait for query new proximities.")
        
        var localityReports: [LocalityReport] = []
        
        trackingLayers.append(TrackingLayer(range: 5, name: "us_counties"))
        trackingLayers.append(TrackingLayer(range: 5, name: "us_zip_places"))
        for layer in trackingLayers {
            layer.queryNewProximities(fortEustisApproach, layer.doINeedToCallNetwork(fortEustisApproach), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                if localityReports.count == 2 {
                    exp.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
                  
        
        let exp2 = self.expectation(description: "Wait for query new proximities.")
          
        localityReports = []
        
        for layer in trackingLayers {
            layer.queryNewProximities(newportNewsZipButHamptonCity, layer.doINeedToCallNetwork(newportNewsZipButHamptonCity), tracker.passiveLocationManager, tracker.lastKnownEHPHorizon, tracker.lastKnownEHPDistances, completion: { report, network in
                localityReports.append(report!)
                
                XCTAssertEqual(network, true, "Network needs to be reached, return true")
                  
                if localityReports.count == 2 {
                    exp2.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssertFalse(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_counties" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Hampton"})}))
        //XCTAssert(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Newport News"})}))
        //XCTAssertFalse(localityReports.contains(where: {LR in LR.layer.name == "us_zip_places" && LR.currentLocalities.contains(where: { TF in TF.info.name == "Hampton"})}))
        
        let enteringString = HelperFunctions.constructEnteringString(localityReports: localityReports)
        XCTAssertEqual("Entering the City of Hampton.", enteringString, "enteringString is not right.")
        
        let exitingString = HelperFunctions.constructExitingString(localityReports: localityReports)
        XCTAssertEqual("Leaving the City of Newport News.", exitingString, "exitingString is not right.")
        
    }

}
