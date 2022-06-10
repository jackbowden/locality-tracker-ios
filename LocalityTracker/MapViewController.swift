//
//  MapViewController.swift
//  LocalityTrackerNav
//
//  Created by Jack Bowden on 3/2/22.
//

import Foundation
import UIKit
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import Turf
import CoreLocation
import InAppSettingsKit

class MapViewController: UIViewController {

    @IBOutlet var mapView: MapView! //var mapView: MapView!
    var tracker: Tracker!
    
    var lastLocalityReportsReceived: [LocalityReport] = []
    
    var polylineAnnotationManager: PolylineAnnotationManager?
    var electronicHorizionLineMarkers: [PolylineAnnotation] = []
    
    var currentLocalityLabel: UILabel?
    var currentRoadNameLabel: UILabel?
    var styleToggle: UISegmentedControl?
        
    var layersLeftToFetch = 0
        
    // TODO: remove cycle button when there's nothing to cycle
    // TODO: put source thing back
    // TODO: add text label bars for each locality there is on map
    
    var currentSealImageName: String = ""
    
    var currentDisplayLayer = "us_counties"
    
    let spinner: SpinnerView = SpinnerView(frame: CGRect(x:0, y: 0, width: 120, height: 120))
    
    var coolPitch: CGFloat = 30
    var targetCoordinate: CLLocationCoordinate2D? = nil
    var targetFeat: TrackingFeature? = nil
    var targetReport: LocalityReport? = nil
    var lastPlaceTapped: CLLocationCoordinate2D? = nil
    
    var coordBank: [CLLocationCoordinate2D] = []
    
    let imageView = UIImageView(image: nil)
    
    let cycleButton: UIButton = {
        let cycleButton = UIButton()
        cycleButton.frame = CGRect(x: 320, y: 70, width: 100, height: 30) //y was 130, x was 20
        cycleButton.backgroundColor = UIColor(red: 0.973, green: 0.329, blue: 0.294, alpha: 1)
        cycleButton.isSelected = false   // optional(because by default sender.isSelected is false)
        cycleButton.setTitle("Cycle", for: .normal)
        cycleButton.setTitleColor(.white, for: .normal)
        cycleButton.layer.cornerRadius = 4
        cycleButton.isHidden = !UserDefaults.standard.bool(forKey: "track_localities_master_switch")
        cycleButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        cycleButton.addTarget(self, action: #selector(handleToggleCycle), for: .touchUpInside)
        return cycleButton
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Map"
            
        // Define center coord, zoom, pitch, bearing
        let cameraOptions = CameraOptions(center: CLLocationCoordinate2D(latitude: 37.28, longitude: -76.67),
                                                  zoom: 8,
                                                  pitch: coolPitch)
        // Pass camera options to map init options
        let options = MapInitOptions(cameraOptions: cameraOptions)
        // Pass options when initializing the map
        mapView = MapView(frame: view.bounds, mapInitOptions: options)
        
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearingSource = .heading //.course
        mapView.ornaments.options.scaleBar.visibility = OrnamentVisibility.hidden
        mapView.ornaments.options.compass.position = .bottomRight
        
        cycleButton.setTitle(currentDisplayLayer, for: .normal)
        
        view.addSubview(mapView)
        mapView.addSubview(cycleButton)
        
        spinner.center = view.convert(view.center, from: view.superview)
        
        polylineAnnotationManager = mapView.annotations.makePolylineAnnotationManager()
        
        loadCurrentLocalityLabel()
        loadCurrentRoadNameLabel()
        loadStyleButton()
        
        if UserDefaults.standard.bool(forKey: "demo_mode") {
            mapView.gestures.options.doubleTapToZoomInEnabled = true
            mapView.gestures.options.doubleTouchToZoomOutEnabled = true
            mapView.gestures.options.quickZoomEnabled = true
            mapView.gestures.options.pitchEnabled = true //was false
            mapView.gestures.options.panEnabled = true // TODO: whats scroll options?
            mapView.gestures.options.pinchEnabled = true
            mapView.gestures.options.pinchRotateEnabled = true
        } else {
            mapView.gestures.options.doubleTapToZoomInEnabled = false
            mapView.gestures.options.doubleTouchToZoomOutEnabled = false
            mapView.gestures.options.quickZoomEnabled = false
            mapView.gestures.options.pitchEnabled = true //was false
            mapView.gestures.options.panEnabled = false // TODO: whats scroll options?
            mapView.gestures.options.pinchEnabled = false
            mapView.gestures.options.pinchRotateEnabled = false
        }
        
        imageView.frame = CGRect(x: 15, y: 620, width: 150, height: 150) //was 655
        
        tracker = Tracker()
        tracker.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingDidChange(notification:)), name: Notification.Name.IASKSettingChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdatePassiveLocation), name: .passiveLocationManagerDidUpdate, object: nil)

        mapView.gestures.delegate = self
        
        updateBarTintColor()
                
        lazy var passiveLocationProvider = PassiveLocationProvider(locationManager: tracker.passiveLocationManager)
        let locationProvider: LocationProvider = passiveLocationProvider
        mapView.location.overrideLocationProvider(with: locationProvider)
        
        tracker.updateTrackerSettings()
        
//        speedLimitView.frame = CGRect(x: 350, y: 70, width: 75, height: 150)
//        view.addSubview(speedLimitView)
                
        roadShieldView.frame = CGRect(x: 25, y: 63, width: 50, height: 50)
        view.addSubview(roadShieldView)
        
        // Stops app from going to sleep
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    let speedLimitView = SpeedLimitView()
    var roadShieldView = UIImageView(image: nil)
    var roadSignURLsaved: URL?
    
    var currentInterstateRoadName: String = ""
    
    //VisualInstruction(text: "lol", maneuverType: nil, maneuverDirection: nil, components: , degrees: nil)
    
    func fixedInterstateName(_ identifier: String) -> String {
        let convertedToNum = Double(identifier.filter("0123456789.".contains))
        var cardinal = identifier.components(separatedBy: CharacterSet.decimalDigits).joined()
        let num = identifier.filter("0123456789.".contains)
    
        switch cardinal {
        case "W":
            cardinal = " West"
        case "E":
            cardinal = " East"
        case "N":
            cardinal = " North"
        case "S":
            cardinal = " South"
        default:
            cardinal = ""
        }
        
        if convertedToNum! >= 100 {
            return "\(identifier.prefix(1)) \(identifier.suffix(2))\(cardinal)"
        }
        return "\(num)\(cardinal)"
    }
    
    @objc func didUpdatePassiveLocation(_ notification: Notification) {
        // Set the sign standard of the speed limit UI components
        // to the standard posted by PassiveLocationManager
        // speedLimitView.signStandard = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.signStandardKey] as? SignStandard
        // Set the value of the speed limit UI component to the value
        // posted by PassiveLocationManager
        // speedLimitView.speedLimit = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.speedLimitKey] as? Measurement<UnitSpeed>
        
        if !UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
            return
        }
        
//        if let distances = tracker.lastKnownEHPDistances {
//            for distance in distances {
//                let meta = tracker.passiveLocationManager.roadObjectStore.roadObject(identifier: distance.identifier)
//                switch distance {
//                case .point(let identifier, let kind, let distance):
//                    print(distance)
//
//                case .gantry(let identifier, let kind, let distance):
//                    print(distance)
//                case .polygon(let identifier, let kind, let distanceToNearestEntry, let distanceToNearestExit, let isInside):
//                    print(distance)
//                case .subgraph(let identifier, let kind, let distanceToNearestEntry, let distanceToNearestExit, let isInside):
//                    print(distance)
//                case .line(let identifier, let kind, let distanceToEntry, let distanceToExit, let distanceToEnd, let isEntryFromStart, let length):
//                    let roadObject = tracker.passiveLocationManager.roadObjectStore.roadObject(identifier: identifier)
//
//                    switch kind {
//                    case .bridge:
//                        print("ITS A BRIDGE")
//                    case .tunnel(let tun):
//                        print("ITS A TUNNEL: \(tun?.name)")
//                    case .incident(let lol):
//                        print(lol?.kind)
//                    default: continue
//
//                    }
//                    print(distance)
//                }
//            }
//        }
//        print("\n")
        
        
        let roadSignImage = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.routeShieldRepresentationKey] as? MapboxDirections.VisualInstruction.Component.ImageRepresentation
        
        if let shieldname = roadSignImage?.shield?.name {
            if shieldname == "us-interstate" {
                // we're on an interstate
                if currentInterstateRoadName.isEmpty || currentInterstateRoadName != (roadSignImage?.shield!.text)! {
                    tracker.screecher.play(enteredstring: "Boarding Interstate \(fixedInterstateName((roadSignImage?.shield!.text)!))", alert: false, interupt: true)
                    currentInterstateRoadName = (roadSignImage?.shield!.text)!
                }
            } else {
                if !currentInterstateRoadName.isEmpty {
                    tracker.screecher.play(enteredstring: "Alighting Interstate \(fixedInterstateName(currentInterstateRoadName))", alert: false, interupt: true)
                    currentInterstateRoadName = ""
                }
            }
        } else {
            if !currentInterstateRoadName.isEmpty {
                tracker.screecher.play(enteredstring: "Alighting Interstate \(fixedInterstateName(currentInterstateRoadName))", alert: false, interupt: true)
                currentInterstateRoadName = ""
            }
        }
        
        if let name = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.roadNameKey] as? String {
            if name.isEmpty {
                currentRoadNameLabel!.text = "Street name unknown"
            } else {
                currentRoadNameLabel!.text = name
            }
        }
        
        
        if let url = roadSignImage?.imageURL() {
            if roadSignURLsaved != url {
                getData(from: url) { data, response, error in
                    guard let data = data, error == nil else { return }
                    let myResponse = response as! HTTPURLResponse
                    DispatchQueue.main.async() { [weak self] in
                        if myResponse.statusCode == 200 {
                            self?.roadShieldView.removeFromSuperview()
                            self?.roadShieldView.image = UIImage(data: data)
                            self?.mapView.addSubview(self!.roadShieldView)
                            self?.roadSignURLsaved = url
                        } else {
                            self?.roadShieldView.removeFromSuperview()
                            self?.roadSignURLsaved = nil
                        }
                    }
                }
            }
        } else {
            roadShieldView.removeFromSuperview()
            roadSignURLsaved = nil
        }
    
    }
    
    @objc func handleToggleCycle(sender: UIButton) {
        
        var layers = tracker.trackingLayers.makeIterator()
        while let layer = layers.next() {
            if layer.name == currentDisplayLayer {
                break
            }
        }
        
        if let layer = layers.next() {
            currentDisplayLayer = layer.name
        } else {
            currentDisplayLayer = tracker.trackingLayers[0].name
        }
        
        cycleButton.setTitle(currentDisplayLayer, for: .normal)
        
        if currentDisplayLayer == "all" {
            // TODO: //paintBoundaryLineOnly(lastLocalityReportsReceived.first(where: {lR in lR.layer.name == currentDisplayLayer})!, rest: lastLocalityReportsReceived)
            setCameraOnWholeOfAllCurrentLocalitiesInLocalityReport(lastLocalityReportsReceived)
            // TODO: need to implement label for all
            // TODO: need to implement logo for all
        } else {
            if let localityReportToDisplay = lastLocalityReportsReceived.first(where: {lR in
                lR.layer.name == currentDisplayLayer
            }) {
                if !UserDefaults.standard.bool(forKey: "show_all_lines") {
                    paintBoundaryLineOnly(toPaint: [localityReportToDisplay], toEnsureUnpainted: lastLocalityReportsReceived)
                } else {
                    paintBoundaryLines([localityReportToDisplay])
                }
                setCurrentLocalityLabel(localityReportToDisplay)
                if Bool(truncating: (self.styleToggle?.selectedSegmentIndex ?? 0) as NSNumber) {
                    setCameraOnElectronicHorizonLine()
                } else {
                    setCameraOnWholeOfFirstCurrentLocalityInLocalityReport(localityReportToDisplay)
                }
                displayLogoOfFirstCurrentLocalityInLocalityReport(localityReportToDisplay)
            }
        }
    }
    
    @objc func settingDidChange(notification: Notification?) {
        if UserDefaults.standard.bool(forKey: "mute_preference") {
            tracker.screecher.shutup()
        }
        
        if UserDefaults.standard.bool(forKey: "track_localities_master_switch") {
            view.addSubview(spinner) // an incoming locality report should turn this off
            currentLocalityLabel?.text = "Waiting for location update."
            cycleButton.isHidden = false
            styleToggle?.isHidden = false
            currentRoadNameLabel?.isHidden = false
            
            lazy var passiveLocationProvider = PassiveLocationProvider(locationManager: tracker.passiveLocationManager)

            if UserDefaults.standard.bool(forKey: "demo_mode") {
                print("Setting to demo mode")
                currentLocalityLabel?.text = "Tap to begin."
                mapView.gestures.options.doubleTapToZoomInEnabled = true
                mapView.gestures.options.doubleTouchToZoomOutEnabled = true
                mapView.gestures.options.quickZoomEnabled = true
                mapView.gestures.options.pitchEnabled = true //was false
                mapView.gestures.options.panEnabled = true // TODO: whats scroll options?
                mapView.gestures.options.pinchEnabled = true
                mapView.gestures.options.pinchRotateEnabled = true
            } else {
                currentLocalityLabel?.text = "Setting to real mode."
                mapView.gestures.options.doubleTapToZoomInEnabled = false
                mapView.gestures.options.doubleTouchToZoomOutEnabled = false
                mapView.gestures.options.quickZoomEnabled = false
                mapView.gestures.options.pitchEnabled = true //was false
                mapView.gestures.options.panEnabled = false // TODO: whats scroll options?
                mapView.gestures.options.pinchEnabled = false
                mapView.gestures.options.pinchRotateEnabled = false
                
                if let targetDisplayLocality = lastLocalityReportsReceived.first(where: {lR in
                    lR.layer.name == currentDisplayLayer
                }) {
                    if !UserDefaults.standard.bool(forKey: "show_all_lines") {
                        paintBoundaryLineOnly(toPaint: [targetDisplayLocality], toEnsureUnpainted: lastLocalityReportsReceived)
                    } else {
                        paintBoundaryLines(lastLocalityReportsReceived)
                    }
                    setCurrentLocalityLabel(targetDisplayLocality)
                    
                    if lastLocalityReportsReceived.isEmpty || !UserDefaults.standard.bool(forKey: "demo_mode") {
                        if Bool(truncating: (self.styleToggle?.selectedSegmentIndex ?? 0) as NSNumber) {
                            setCameraOnElectronicHorizonLine()
                        } else {
                            setCameraOnWholeOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
                        }
                    }
                    displayLogoOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
                }
            }
            
            spinner.removeFromSuperview()
        } else {
            currentLocalityLabel?.text = "Tracker Off. Enable in settings."
            removeLogo()
            tracker.screecher.shutup()
            removeBoundaryLines(lastLocalityReportsReceived)
            roadShieldView.removeFromSuperview()
            cycleButton.isHidden = true
            styleToggle?.isHidden = true
            currentRoadNameLabel?.isHidden = true
            //UserDefaults.standard.set(false, forKey: "demo_mode")
        }
        tracker.updateTrackerSettings()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateBarTintColor()
        // TODO: make app dark/light thing automatically change -- right now it doesn't automatically change
    }
    
    private func updateBarTintColor() {
        if #available(iOS 13.0, *) {
            //self.tabBar.backgroundColor = UITraitCollection.current.userInterfaceStyle == .dark ? .black : .white
            if UITraitCollection.current.userInterfaceStyle == .dark {
                mapView.mapboxMap.loadStyleURI(StyleURI(url: (NSURL(string: "mapbox://styles/jakallan3/ckl1rbh6k0qgn17mu9mehy9z7") as URL?)!)!)
            } else {
                mapView.mapboxMap.loadStyleURI(StyleURI(url: (NSURL(string: "mapbox://styles/jakallan3/cl0lugi4h001x15o49l7r3h9w") as URL?)!)!)
            }
        }
                
        if let targetDisplayLocality = lastLocalityReportsReceived.first(where: {lR in
            lR.layer.name == currentDisplayLayer
        }) {
            if !UserDefaults.standard.bool(forKey: "show_all_lines") {
                paintBoundaryLineOnly(toPaint: [targetDisplayLocality], toEnsureUnpainted: lastLocalityReportsReceived)
            } else {
                paintBoundaryLines(lastLocalityReportsReceived)
            }
        }
    }
}

extension MapViewController: GestureManagerDelegate {
    func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
        if gestureType != .singleTap || !UserDefaults.standard.bool(forKey: "demo_mode") {
            return
        }
        let tapPoint: CGPoint = gestureManager.singleTapGestureRecognizer.location(in: self.mapView)
        let tapCoordinate: CLLocationCoordinate2D = mapView.mapboxMap.coordinate(for: tapPoint)
        print("You tapped at: \(tapCoordinate.latitude), \(tapCoordinate.longitude) and demoMode is \(UserDefaults.standard.bool(forKey: "demo_mode"))")
        
        tracker.manuallyRequestLocalityReport(CLLocation(latitude: tapCoordinate.latitude, longitude: tapCoordinate.longitude))
    }
    
    func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
        return
    }
    
    func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
        return
    }
}

// MARK: Tracker Delegate
extension MapViewController: TrackerDelegate {
    func trackerHasNewLocalityReports(_ tracker: Tracker, localityReports: [LocalityReport], _ passiveLocationManager: PassiveLocationManager?, _ horizon: RoadGraph.Edge?, _ distances: [DistancedRoadObject]?) {
        
        if currentDisplayLayer == "all" {
            paintBoundaryLines(localityReports)
            setCameraOnWholeOfAllCurrentLocalitiesInLocalityReport(localityReports)
            // TODO: need to implement label for all
            // TODO: need to implement logo for all
        } else {
            if let targetDisplayLocality = localityReports.first(where: {lR in
                lR.layer.name == currentDisplayLayer
            }) {
                if !UserDefaults.standard.bool(forKey: "show_all_lines") {
                    paintBoundaryLineOnly(toPaint: [targetDisplayLocality], toEnsureUnpainted: localityReports)
                } else {
                    paintBoundaryLines(localityReports)
                }
                setCurrentLocalityLabel(targetDisplayLocality)
                if lastLocalityReportsReceived.isEmpty || !UserDefaults.standard.bool(forKey: "demo_mode") {
                    if Bool(truncating: (self.styleToggle?.selectedSegmentIndex ?? 0) as NSNumber) {
                        setCameraOnElectronicHorizonLine()
                    } else {
                        setCameraOnWholeOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
                    }
                }
                displayLogoOfFirstCurrentLocalityInLocalityReport(targetDisplayLocality)
            }
        }
        
        if let horizon = horizon, let passiveLocationManager = passiveLocationManager {
            // TODO: consider not running paintLines unless we know for sure that we have a new eh to work with? sometimes eh doesn't get updated but i think the line painting still goes on, giving the perception that eh is updating when it may not be
            electronicHorizionLineMarkers = []
            coordBank = []
            paintLines(passiveLocationManager, horizon)
            
            var combinedLines: [PolylineAnnotation] = []
            combinedLines.append(contentsOf: electronicHorizionLineMarkers)
            polylineAnnotationManager?.annotations.removeAll()
            polylineAnnotationManager?.annotations.append(contentsOf: combinedLines)
        }
        
        lastLocalityReportsReceived = localityReports
        spinner.removeFromSuperview()
    }
    
    func trackerTurnedOff() {
        removeAllPolylines()
        // TODO: is this needed?
    }
    
    func failedToGetLocationUpdate() {
        return
        //spinner.removeFromSuperview()
        // TODO: is this needeed?
    }
    
    func needsToCallNetwork() {
        self.layersLeftToFetch += 1
        DispatchQueue.main.async {
            self.view.addSubview(self.spinner)
        }

        if self.layersLeftToFetch > 0 {
            DispatchQueue.main.async {
                self.imageView.image = nil
                self.currentSealImageName = ""
                self.currentLocalityLabel?.center.x = self.view.center.x

                self.currentLocalityLabel?.text = "Fetching Localities (\(self.layersLeftToFetch) remaining)"
                self.currentLocalityLabel?.isHidden = false
                //self.styleToggle?.isHidden = true
            }
        }
    }
    
    func networkReturnedWithData() {
        DispatchQueue.main.async {
            self.layersLeftToFetch -= 1
            if self.layersLeftToFetch > 0 {
                self.currentLocalityLabel?.text = "Fetching Localities (\(self.layersLeftToFetch) remaining)"
            }
        }
    }
    
    func queryingLayers() {
//        if UserDefaults.standard.bool(forKey: "demo_mode") {
//            view.addSubview(spinner)
//        }
        return
    }
}

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func random() -> UIColor {
        return UIColor(
           red:   .random(),
           green: .random(),
           blue:  .random(),
           alpha: 1.0
        )
    }
    
    var isLight: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.5
    }
}

extension MapViewController {
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
            session.dataTask(with: url, completionHandler: completion).resume()
        }
        
    func downloadImage(from url: URL) {
        self.imageView.removeFromSuperview()
        getData(from: url) { data, response, error in
            guard let data = data, error == nil else { return }
            print(response?.suggestedFilename ?? url.lastPathComponent)
            let myResponse = response as! HTTPURLResponse
            DispatchQueue.main.async() { [weak self] in
                if myResponse.statusCode == 200 {
                    
                    self?.imageView.image = UIImage(data: data)
                    self?.mapView.addSubview(self!.imageView)
                    
                    self?.currentLocalityLabel?.frame.origin.x = 105
                    
                    // TODO: i encode but i dont decode :/
                    let encoder = JSONEncoder()
                    do {
                        let stuff = try encoder.encode(data)
                        let defaults = UserDefaults.standard
                        defaults.set(stuff, forKey: "savedSeal")
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                } else {
                    self?.imageView.removeFromSuperview()
                    self?.currentLocalityLabel?.center.x = (self?.view.center.x)!
                }
            }
        }
    }
    
    func displayLogo(_ feat: TrackingFeature) {
        var newImageName = ""
        //var type = "seals"
        newImageName = "\(feat.info.name ) \(feat.info.type ?? "")"
        if feat.info.type?.lowercased() == "state" || feat.info.type?.lowercased() == "commonwealth" {
            newImageName = "\(feat.info.name )"
            //type = "flags"
        }
        if currentSealImageName != newImageName {
            currentSealImageName = newImageName
            if let seal = feat.info.sealURL {
                self.downloadImage(from: URL(string: seal)!)
            }
        }
    }
    
    func displayLogoOfFirstCurrentLocalityInLocalityReport(_ report: LocalityReport) {
        if let feat = report.currentLocalities.first {
            displayLogo(feat)
        } else {
            removeLogo()
        }
    }
    
    func removeLogo() {
        self.imageView.removeFromSuperview()
        if self.currentLocalityLabel?.frame.origin.x == 105 {
            self.currentLocalityLabel?.center.x = (self.view.center.x)
        }
    }
}
