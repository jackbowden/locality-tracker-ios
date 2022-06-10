//
//  MockDelegateTests.swift
//  LocalityTrackerNavTests
//
//  Created by Jack Bowden on 3/29/22.
//

import XCTest
import CoreLocation
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
@testable import LocalityTrackerNav

class MockDelegateTests: XCTestCase {
    
    var tracker = Tracker()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        tracker = Tracker()
        
//        let mockDelegate = MockTrackerDelegate(testCase: self)
//        tracker.delegate = mockDelegate
        
        UserDefaults.standard.set(true, forKey: "demo_mode")
        UserDefaults.standard.set(true, forKey: "mute_preference")
        
        tracker.layers = ["us_states", "us_counties", "us_places", "us_zip_places", "us_military_bases"]
        
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateLocation), name: .passiveLocationManagerDidUpdate, object: nil)

    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
//    let I64YorkTowardsNNInJCC: CLLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.24519300, longitude: -76.63711400), altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: ((25*1609.0)/60/60)*0, timestamp: Date()) // speed limit example CLLocation object
    
    let I664SouthInSuffolkTowardsChesapeake: CLLocation = CLLocation(latitude: 36.860322, longitude: -76.431467)
    let yorkCountyNotOnRoad: CLLocation = CLLocation(latitude: 37.28, longitude: -76.67)
    let I64YorkTowardsNNInJCC: CLLocation = CLLocation(latitude: 37.24519300, longitude: -76.63711400)
    let I64EastYorkTowardsNN: CLLocation = CLLocation(latitude: 37.21703183, longitude: -76.60168221)
    //let I95NorthTowardsWoodbridge: CLLocation = CLLocation(latitude: 38.599044, longitude: -77.313710)
    //let I95SouthTowardsAshland: CLLocation = CLLocation(latitude: 37.794163, longitude: -77.460632)
    let I95SouthTowardsAshland: CLLocation = CLLocation(latitude: 37.799455, longitude: -77.461065)
    let FortEustisDDL: CLLocation = CLLocation(latitude: 37.146034, longitude: -76.571349)
    let FortEustisShellabargerDrOutbound: CLLocation = CLLocation(latitude: 37.158510, longitude: -76.565283)
    let I64EastHamptonTowardsNorfolk: CLLocation = CLLocation(latitude: 36.970270, longitude: -76.300364)
    let I64EastNorfolkAfterHRBT: CLLocation = CLLocation(latitude: 36.967098, longitude: -76.296738)
    let I64WestNorfolkTowardsHampton: CLLocation = CLLocation(latitude: 36.967156, longitude: -76.296123)

    func testA_LocalityReports() throws {
        // Arrange
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.populateLayers()
        
        // Act
        mockDelegate.expectLocalityReports()
        tracker.manuallyRequestLocalityReport(yorkCountyNotOnRoad, test: true)
        
        // Assert
        waitForExpectations(timeout: 25)
                
        let result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 5)
    }
    
    func testB_ElectronicHorizon() throws {
        // Arrange
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.populateLayers()

        // Act
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        tracker.manuallyRequestLocalityReport(I664SouthInSuffolkTowardsChesapeake, test: true)
        
        // Assert
        waitForExpectations(timeout: 25)
        
        let result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 5)
        //XCTAssertNotNil(mockDelegate.horizon) // TODO: this has collison
    }
    
    func testC_HelpingFunctionsApproachStringMeasurement() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.layers = ["us_counties"]
        tracker.trackingLayers = tracker.trackingLayers.filter({ tL in
            tL.name == "us_counties"
        })
        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        
        tracker.manuallyRequestLocalityReport(I664SouthInSuffolkTowardsChesapeake, test: true)
        waitForExpectations(timeout: 20)
        
        let result = try XCTUnwrap(mockDelegate.localityReports)
        
        measure {
            _ = HelperFunctions.constructApproachingString(localityReports: result)
        }
    }
    
    func testD_ChesapeakeApproachingStringCheck() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_counties"]
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 1)
        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        tracker.manuallyRequestLocalityReport(I664SouthInSuffolkTowardsChesapeake, test: true)
        waitForExpectations(timeout: 25)
        
        
        let result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 1)
        
        // VOICE
        let approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertFalse(approachingString.contains("Portsmouth"), "Portsmouth is not supposed to be here because it's not on the electronic horizon path for being crossed into.")
        
        XCTAssertEqual("Approaching the City of Chesapeake. Distance: half a mile. ", approachingString, "approachingString is not right.") // used to be half a mile???
        
        // NOTIFCATIONS
//        let chesapeake = result.first(where: { lR in lR.layer.name == "us_counties"})?.approachingAlerts.first(where: {aR in aR.alertingFeature.info.name == "Chesapeake"})
//
//        XCTAssertNotNil(HelperFunctions.GetProximityString(chesapeake!))
//
//        XCTAssertEqual("Approaching City of Chesapeake. Location: I 664 South Hampton Roads Beltway. Distance: half a mile.", HelperFunctions.GetProximityString(chesapeake!), "notificationApproachingString is not right.")
    }
        
    func testE_YorkNewportNewsLocalityFilterProblem() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_counties", "us_zip_places"]
        
        UserDefaults.standard.set(50, forKey: "distance_update_sensitivity_value")
        
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 2)
                
        tracker.passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 400, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 2))
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(I64YorkTowardsNNInJCC, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        for report in mockDelegate.localityReports! {
            for locality in report.currentLocalities {
                locality.neuter()
            }
        }
                        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        tracker.manuallyRequestLocalityReport(I64EastYorkTowardsNN, test: true)
        waitForExpectations(timeout: 25)
        
        var result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 2)
        
        // VOICE
        var approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("York County"))
        XCTAssertTrue(approachingString.contains("Newport News"))
        XCTAssertNotEqual(approachingString, "Approaching Newport News. Distance: half a mile. ")
        XCTAssertEqual(approachingString, "Approaching York County and Newport News. Distance: half a mile. ")
        
        
        result = try XCTUnwrap(mockDelegate.localityReports)
        approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertEqual(result.count, 2)
    }
    
    func testF_YorkNewportNewsLocalityButWithoutMilitaryBaseAdjustmentForEHP() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_counties", "us_zip_places"]
        
        UserDefaults.standard.set(50, forKey: "distance_update_sensitivity_value")
        
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 2)
                
        tracker.passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 0))
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(I64YorkTowardsNNInJCC, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        for report in mockDelegate.localityReports! {
            for feature in report.currentLocalities {
                feature.neuter()
            }
        }
                        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        tracker.manuallyRequestLocalityReport(I64EastYorkTowardsNN, test: true)
        waitForExpectations(timeout: 25)
        
        let result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 2)
        
        let approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("York County"))
        XCTAssertTrue(approachingString.contains("Newport News"))
        XCTAssertNotEqual(approachingString, "Approaching the City of Newport News. Distance: one mile. ")
        XCTAssertNotEqual(approachingString, "Approaching York County. Distance: half a mile. Approaching the City of Newport News. Distance: one mile. ")
        XCTAssertEqual(approachingString, "Approaching York County and Newport News. Distance: half a mile. ")
    }
    
    func testG_AshlandBoundaryParellelWithRoadProblem() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_places"]
        
        UserDefaults.standard.set(0, forKey: "distance_update_sensitivity_value")
        
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 2)
                
        tracker.passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 0))
        
//        mockDelegate.expectLocalityReports()
//        tracker.queryLayers(CLLocation(latitude: 37.808526, longitude: -77.460788), tracker.trackingLayers)
//        waitForExpectations(timeout: 40)
        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        // Launch problem for Ashland
        tracker.manuallyRequestLocalityReport(I95SouthTowardsAshland, test: true)
        waitForExpectations(timeout: 40)
        
        var result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 2)
        
        var approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("Ashland"))
        var numberOfSetInAshland = approachingString
        
        // Wait for Ashland to come around again
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        waitForExpectations(timeout: 40)
        
        result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 2)
        
        approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("Ashland"))
        XCTAssertFalse(approachingString.contains("two miles. "))
        XCTAssertNotEqual(approachingString, numberOfSetInAshland)
        numberOfSetInAshland = approachingString
        
//        // Wait for Ashland to come around one more time
//        mockDelegate.expectElectronicHorizon()
//        mockDelegate.expectLocalityReports()
//        mockDelegate.expectApproachingAlerts()
//
//        waitForExpectations(timeout: 70)
//
//        result = try XCTUnwrap(mockDelegate.localityReports)
//        XCTAssertEqual(result.count, 2)
//
//        approachingString = HelperFunctions.constructApproachingString(localityReports: result)
//        XCTAssertTrue(approachingString.contains("Ashland"))
//        XCTAssertFalse(approachingString.contains("one mile. "))
//        XCTAssertFalse(approachingString.contains("two miles. "))
//        XCTAssertNotEqual(approachingString, numberOfSetInAshland)
        
    }
    
    func testH_FortEustisExitShellabargerDisjointedAnnouncementsProblem() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_places", "us_zip_places", "us_military_bases"]
        
        UserDefaults.standard.set(0, forKey: "distance_update_sensitivity_value")
        
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 3)
                
        tracker.passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 600, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 2))
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(FortEustisDDL, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        // Launch problem for Ashland
        tracker.manuallyRequestLocalityReport(FortEustisShellabargerDrOutbound, test: true)
        waitForExpectations(timeout: 25)
        
        var result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 3)
        
        let approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("Newport News"))
        XCTAssertEqual(approachingString, "Approaching Newport News. Boundary crossing imminent! ")
        
        // Wait to come around again
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectBoundaryCrossingAlert()
        
        waitForExpectations(timeout: 40)
        
        result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 3)
        
        let exitingString = HelperFunctions.constructExitingString(localityReports: result)
        XCTAssertEqual(exitingString, "Leaving Fort Eustis and federal jurisdiction. ")
        
//        // Wait to come around again
//        mockDelegate.expectElectronicHorizon()
//        mockDelegate.expectLocalityReports()
//        mockDelegate.expectBoundaryCrossingAlert()
//
//        waitForExpectations(timeout: 10)
//
//        result = try XCTUnwrap(mockDelegate.localityReports)
//        XCTAssertEqual(result.count, 3)
//
//        exitingString = HelperFunctions.constructExitingString(localityReports: result)
//        XCTAssertNotEqual(exitingString, "Leaving federal jurisdiction.")
    }
    
    func testI_ApproachingTwoMilesButActuallyNextToIt() throws {
        let mockDelegate = MockTrackerDelegate(testCase: self)
        tracker.delegate = mockDelegate
        tracker.dumpSavedLayers()
        tracker.layers = ["us_counties", "us_zip_places"]
        
        UserDefaults.standard.set(50, forKey: "distance_update_sensitivity_value")
        
        tracker.populateLayers()
        
        XCTAssertEqual(tracker.trackingLayers.count, 2)
                
        tracker.passiveLocationManager.startUpdatingElectronicHorizon(with: ElectronicHorizonOptions(length: 3200, expansionLevel: 0, branchLength: 0, minTimeDeltaBetweenUpdates: 0))
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(I64WestNorfolkTowardsHampton, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(I64EastHamptonTowardsNorfolk, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        mockDelegate.expectLocalityReports()
        tracker.queryLayers(I64EastNorfolkAfterHRBT, tracker.trackingLayers)
        waitForExpectations(timeout: 25)
        
        mockDelegate.expectElectronicHorizon()
        mockDelegate.expectLocalityReports()
        mockDelegate.expectApproachingAlerts()
        
        tracker.manuallyRequestLocalityReport(I64WestNorfolkTowardsHampton, test: true)
        waitForExpectations(timeout: 25)
        
        let result = try XCTUnwrap(mockDelegate.localityReports)
        XCTAssertEqual(result.count, 2)
        
        let approachingString = HelperFunctions.constructApproachingString(localityReports: result)
        XCTAssertTrue(approachingString.contains("Hampton"))
        XCTAssertNotEqual(approachingString, "Approaching the City of Hampton. Distance: two miles. ")
        //XCTAssertEqual(approachingString, "Approaching York County and Newport News. Distance: half a mile. ")
    }


    @objc func didUpdateLocation(_ notification: Notification) {
        guard
            let newLocation = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.locationKey] as? CLLocation
            //let matches = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.matchesKey] as? [Match],
            //let result = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.mapMatchingResultKey] as? MapMatchingResult
            //let newLocationRaw = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.rawLocationKey] as? CLLocation
        else { return }
        
        print(newLocation)
        print("\n")
        
        return
    }
}

class MockTrackerDelegate: TrackerDelegate {
    var localityReports: [LocalityReport]?
    var horizon: RoadGraph.Edge?
    
    private var expectation: XCTestExpectation?
    private var horizonExpectation: XCTestExpectation?
    private var approachingExpectation: XCTestExpectation?
    private var boundaryCrossingExpectation: XCTestExpectation?
    private let testCase: XCTestCase
    
    init(testCase: XCTestCase) {
        self.testCase = testCase
    }
    
    func expectLocalityReports() {
        expectation = testCase.expectation(description: "Expect locality reports.")
    }
    
    func expectElectronicHorizon() {
        horizonExpectation = testCase.expectation(description: "Expect electronic horizon.")
    }
    
    func expectApproachingAlerts() {
        approachingExpectation = testCase.expectation(description: "Expect approaching alerts.")
    }
    
    func expectBoundaryCrossingAlert() {
        boundaryCrossingExpectation = testCase.expectation(description: "Expect boundary crossing alert.")
    }
    
    func trackerHasNewLocalityReports(_ tracker: Tracker, localityReports: [LocalityReport], _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?) {
        
        if expectation != nil {
            self.localityReports = localityReports
            
            expectation?.fulfill()
            expectation = nil
        }
        
        if boundaryCrossingExpectation != nil {
            for report in localityReports {
                if !report.enteredLocalities.isEmpty || !report.exitedLocalities.isEmpty {
                    self.localityReports = localityReports
                    
                    boundaryCrossingExpectation?.fulfill()
                    boundaryCrossingExpectation = nil
                }
            }
        }
        
        if horizonExpectation != nil {
            if horizon?.identifier != nil {
                if tracker.passiveLocationManager.roadGraph.edgeShape(edgeIdentifier: horizon!.identifier)?.coordinates.contains((passiveLocationManager?.location!.coordinate)!) != nil {
                    self.horizon = horizon
                    self.localityReports = localityReports
                    
                    horizonExpectation?.fulfill()
                    horizonExpectation = nil
                }
            }
        }
        
        if approachingExpectation != nil {
            if localityReports.first(where: { lR in
                lR.approachingAlerts.contains(where: { aR in
                    aR.finalRoadName != nil
                })}) != nil {
                self.localityReports = localityReports
            
                self.approachingExpectation?.fulfill()
                self.approachingExpectation = nil
            }
//            } else {
//                tracker.manuallyRequestLocalityReport(localityReports.first!.coordinate, test: true)
//            }
        }
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
