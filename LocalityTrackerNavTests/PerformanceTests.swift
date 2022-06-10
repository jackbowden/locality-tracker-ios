//
//  NewTests.swift
//  LocalityTrackerNavTests
//
//  Created by Jack Bowden on 3/15/22.
//

import XCTest
import CoreLocation
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
@testable import LocalityTrackerNav

class PerformanceTests: XCTestCase, TrackerDelegate {
    var latestLocalityReportReceived: [LocalityReport]?

    var expectationNewLocalityReports: XCTestExpectation?

    var tracker: Tracker = Tracker()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        UserDefaults.standard.set(true, forKey: "demo_mode")
        UserDefaults.standard.set(true, forKey: "mute_preference")
        tracker.updateTrackerSettings()
        tracker.delegate = self
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        //tracker.trackingLayers = []
    }

    let yorkCounty: CLLocation = CLLocation(latitude: 37.28, longitude: -76.67)

    func testA() throws {
        tracker.layers = ["us_counties"]
        //UserDefaults.standard.removeObject(forKey: "us_counties layer")
        
        measure {
            expectationNewLocalityReports = expectation(description: "Wait for query new proximities.")
            tracker.manuallyRequestLocalityReport(yorkCounty)
            waitForExpectations(timeout: 20)
        }

        let report = try XCTUnwrap(latestLocalityReportReceived)
        
        if let report = report.first(where: {lR in lR.layer.name == "us_counties"}) {
            XCTAssertEqual(report.currentLocalities.count, 1, "Not inside just one locality")

            XCTAssertEqual(report.layer.name, "us_counties", "Layer name is not us_counties")

            XCTAssertEqual(report.currentLocalities[0].info.name, "York", "York County is not the expected current locality")
            XCTAssertEqual(report.neighboringLocalities.contains(where: { feature in
                feature.info.name == "James City"
            }), true, "James City County is not a expected neighbor")

            XCTAssertEqual(report.exitedLocalities.count, 0, "Exited localities should be empty")
            //XCTAssertEqual(report.enteredLocalities.count, 1, "Entered localities should report one locality because of the silly glitch we're stubborn to fix") // todo: fix this to be 0
        }
    }
    
    func testB_yorkCountyAgain() throws {
        tracker.layers = ["us_counties"]
        //XCTAssertEqual(tracker.trackingLayers.count, 1, "Thought I already had one county layer to start with.")
        tracker.trackingLayers = tracker.trackingLayers.filter({ tL in
            tL.name == "us_counties"
        })
        measure {
            expectationNewLocalityReports = expectation(description: "Wait for query new proximities.")
            tracker.manuallyRequestLocalityReport(yorkCounty)
            waitForExpectations(timeout: 20)
        }
    }
    
    let cityOfWilliamsburg: CLLocation = CLLocation(latitude: 37.270787, longitude: -76.709781)
    
    func testC_cityOfWilliamsburg() throws {
        tracker.layers = ["us_counties"]
        //XCTAssertEqual(tracker.trackingLayers.count, 1, "Thought I already had one county layer to start with.")
        tracker.trackingLayers = tracker.trackingLayers.filter({ tL in
            tL.name == "us_counties"
        })
        measure {
            expectationNewLocalityReports = expectation(description: "Wait for query new proximities.")
            tracker.manuallyRequestLocalityReport(cityOfWilliamsburg)
            waitForExpectations(timeout: 20)
        }
    }
    
    func testD_HelpingFunctions() throws {
        tracker.layers = ["us_counties"]
        //XCTAssertEqual(tracker.trackingLayers.count, 1, "Thought I already had one county layer to start with.")
        tracker.trackingLayers = tracker.trackingLayers.filter({ tL in
            tL.name == "us_counties"
        })
        
        expectationNewLocalityReports = expectation(description: "Wait for query new proximities.")
        tracker.manuallyRequestLocalityReport(yorkCounty)
        waitForExpectations(timeout: 20)
        
        XCTAssertNotNil(latestLocalityReportReceived)
        XCTAssertEqual(latestLocalityReportReceived?.first?.coordinate.coordinate.latitude, yorkCounty.coordinate.latitude)
        
        measure {
            HelperFunctions.constructApproachingString(localityReports: latestLocalityReportReceived!)
        }
    }


    @objc func didUpdatePassiveLocation(_ notification: Notification) {
        guard
            let newLocation = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.locationKey] as? CLLocation,
            //let matches = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.matchesKey] as? [Match],
            //let result = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.mapMatchingResultKey] as? MapMatchingResult
            let newLocationRaw = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.rawLocationKey] as? CLLocation
        else { return }
    }


    // MARK: Tracker delegate functions
    func trackerHasNewLocalityReports(_ tracker: Tracker, localityReports: [LocalityReport], _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?) {
        latestLocalityReportReceived = localityReports
        expectationNewLocalityReports?.fulfill()
        expectationNewLocalityReports = nil
    }

    func trackerTurnedOff() {
        return
    }

    func needsToCallNetwork() {
        return
    }

    func networkReturnedWithData() {
        return
    }

    func failedToGetLocationUpdate() {
        return
    }

    func queryingLayers() {
        return
    }
}
