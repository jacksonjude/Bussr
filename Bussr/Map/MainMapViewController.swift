//
//  MainMapViewController.swift
//  Bussr
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import MapKit
import FloatingPanel
import CoreData

let appDelegate = UIApplication.shared.delegate as! AppDelegate

struct DisplayConstants
{
    static let panelTipSize: CGFloat = 80.0
    static let panelHalfSize: CGFloat = 281.0
    static let panelBottomMargin: CGFloat = 5.0
    static let routeInfoPickerViewTag = 618
    static let helpInfoViewTag = 819
    static let mapAlphaValue: CGFloat = 0.85
}

struct MapConstants
{
    static let NextBusMaxLongMetersBeforeHidingStopAnnotations = 4000.0
    static let BARTMaxLongMetersBeforeHidingStopAnnotations = 22000.0
    static let directionPolylineWidth: CGFloat = 5.0
    static let borderPolylineWidth: CGFloat = 6.0
    static let directionZoomMarginPercent: Double = 20.0
    static let stopZoomMarginPercent: Double = 50.0
}

enum AnnotationType
{
    case small
    case large
}

extension CLLocationCoordinate2D
{
    func convertToString() -> String
    {
        return String(self.latitude) + "-" + String(self.longitude)
    }
}

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

extension CLLocationCoordinate2D {
    func heading(to: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude.degreesToRadians
        let lon1 = self.longitude.degreesToRadians
        
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let headingDegrees = atan2(y, x).radiansToDegrees
        if headingDegrees >= 0 {
            return headingDegrees
        } else {
            return headingDegrees + 360
        }
    }
}

extension UIImage {
    func colorized(color : UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context!.setBlendMode(.multiply)
        context!.draw(self.cgImage!, in: rect)
        context!.clip(to: rect, mask: self.cgImage!)
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let colorizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return colorizedImage!
    }
}

class MainMapViewController: UIViewController, MKMapViewDelegate, FloatingPanelControllerDelegate {
    
    @IBOutlet weak var mainMapView: MKMapView!
    
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    
    @IBOutlet weak var predictionTimesNavigationBar: UINavigationBar!
    @IBOutlet weak var predictionTimesLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var refreshButton: UIBarButtonItem!
    @IBOutlet weak var vehicleSelectionButton: UIButton!
    
    @IBOutlet weak var centerOnLocationButton: UIButton!
    @IBOutlet weak var centerOnStopButton: UIButton!
    @IBOutlet weak var centerOnVehicleButton: UIButton!
    
    @IBOutlet weak var predictionBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var predictionTimesProgressView: UIProgressView!
    @IBOutlet weak var predictionTimesProgressViewConstraint: NSLayoutConstraint!
    
    //37.773972
    //37.738802
    let initialLocation = CLLocation(latitude: 37.773972, longitude: -122.438765)
    
    var downloadAllData = false
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    var routeOnLabel: UILabel?
    var updateAllRouteDataOperation: BlockOperation?
    
    var shouldDoInitialCenter = true
    
    var selectedAnnotationLocation: String?
    var stopAnnotations = Dictionary<String,StopAnnotation>()
    var directionPolyline: MKPolyline?
    var borderPolyline: MKPolyline?
    var busAnnotations = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?, headingAnnotationView: MKAnnotationView?)>()
    var vehicleIDs = Array<String>()
    var predictions = Array<PredictionTime>()
    var selectedStopHeading: SelectedStopHeadingAnnotation?
    
    var locationManager = CLLocationManager()
    
    var predictionRefreshTimer: Timer?
    var currentlyAnimatingPredictionTimesProgressView = false
    
    //MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        mainMapView.showsUserLocation = true
        mainMapView.isRotateEnabled = false
        mainMapView.isPitchEnabled = false
        
        setupRouteMapUpdateNotifications()
                
        setupPickerPanel()
        
        if !appDelegate.hasDownloadedData
        {
            self.movePickerPanelPosition(position: .half, animated: false)
            self.downloadAllData = true
        }
        
        setupThemeElements()
        setupCenterMapButtons()
        setupNavItemTitleView()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        
        setupThemeElements()
        reloadAllAnnotations(fetchPredictions: true) //For header annotation update
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.activityIndicator.color = .gray
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            self.predictionTimesLabel.textColor = UIColor.black
            self.centerOnLocationButton.backgroundColor = UIColor.white.withAlphaComponent(DisplayConstants.mapAlphaValue)
            self.centerOnStopButton.backgroundColor = UIColor.white.withAlphaComponent(DisplayConstants.mapAlphaValue)
            self.centerOnVehicleButton.backgroundColor = UIColor.white.withAlphaComponent(DisplayConstants.mapAlphaValue)
        case .dark:
            self.activityIndicator.color = .white
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            self.predictionTimesLabel.textColor = UIColor.white
            self.centerOnLocationButton.backgroundColor = UIColor.black.withAlphaComponent(DisplayConstants.mapAlphaValue)
            self.centerOnStopButton.backgroundColor = UIColor.black.withAlphaComponent(DisplayConstants.mapAlphaValue)
            self.centerOnVehicleButton.backgroundColor = UIColor.black.withAlphaComponent(DisplayConstants.mapAlphaValue)
        }
    }
    
    func darkImageAppend() -> String
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return ""
        case .dark:
            return "Dark"
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return .default
        case .dark:
            return .lightContent
        }
    }
    
    func setupCenterMapButtons()
    {
        centerOnLocationButton.layer.cornerRadius = 8
        centerOnStopButton.layer.cornerRadius = 8
        centerOnVehicleButton.layer.cornerRadius = 8
        self.predictionBarTopConstraint.constant = -1*(self.predictionTimesNavigationBar.frame.size.height)
        self.view.layoutSubviews()
    }
    
    func setupNavItemTitleView()
    {
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 40))
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22.0)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.text = "Map"
        self.mainNavigationItem.titleView = titleLabel
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if downloadAllData
        {
            self.progressAlertView = UIAlertController(title: "Updating Routes", message: "\n", preferredStyle: .alert)
            
            self.present(progressAlertView!, animated: true, completion: {
                let margin: CGFloat = 8.0
                
                let routeOnLabelRect = CGRect(x: 0, y: 48.0, width: self.progressAlertView!.view.frame.width, height: 20)
                self.routeOnLabel = UILabel(frame: routeOnLabelRect)
                self.routeOnLabel!.textAlignment = .center
                self.progressAlertView!.view.addSubview(self.routeOnLabel!)
                
                let progressViewRect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
                self.progressView = UIProgressView(frame: progressViewRect)
                self.progressView!.tintColor = UIColor.blue
                self.progressAlertView!.view.addSubview(self.progressView!)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.addToProgress(notification:)), name: NSNotification.Name("CompletedRoute"), object: nil)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.dismissDownloadDataAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
                
                Task
                {
                    await RouteDataManager.updateAllData()
                }
            })
            
            self.downloadAllData = false
        }
        
        setupThemeElements()
        
        if MapState.routeInfoShowing == .stop
        {
            self.setupPredictionRefreshTimer()
//            self.refreshPredictionNavigationBar()
        }
        
        if shouldDoInitialCenter
        {
            centerMapOnLocation(location: initialLocation, range: 15000, animated: false)
            shouldDoInitialCenter = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.stopPredictionRefreshTimer()
    }
    
    //MARK: - Update Routes
    
    @objc func addToProgress(notification: Notification)
    {
        OperationQueue.main.addOperation {
            self.routeOnLabel?.text = notification.userInfo?["route"] as? String
            self.progressView?.progress = notification.userInfo?["progress"] as? Float ?? 0.0
        }
    }
    
    @objc func dismissDownloadDataAlertView()
    {
        progressAlertView?.dismiss(animated: true, completion: {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CompletedRoute"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            appDelegate.hasDownloadedData = true
            
            if appDelegate.firstLaunch && CLLocationManager.authorizationStatus() != .denied
            {
                self.locationManager.requestWhenInUseAuthorization()
            }
        })
    }
    
    //MARK: - Picker View Show/Hide
    
    var pickerFloatingPanelController: FloatingPanelController?
    var shouldNotAdjustMapForPanelMove = false
    var previousPanelPosition: FloatingPanelPosition = .tip
    
    func setupPickerPanel()
    {
        self.pickerFloatingPanelController = FloatingPanelController()
        
        self.pickerFloatingPanelController?.delegate = self
        
        let pickerContentVC = storyboard!.instantiateViewController(withIdentifier: "RouteInfoPickerViewController") as! RouteInfoPickerViewController
        pickerContentVC.mainMapViewController = self
        
        self.pickerFloatingPanelController?.set(contentViewController: pickerContentVC)
        self.shouldNotAdjustMapForPanelMove = true
        self.pickerFloatingPanelController?.addPanel(toParent: self)
        
        self.pickerFloatingPanelController?.surfaceView.backgroundColor = UIColor.clear
        
        self.view.viewWithTag(DisplayConstants.routeInfoPickerViewTag)?.isHidden = true
        self.view.viewWithTag(DisplayConstants.helpInfoViewTag)?.isHidden = false
        
        self.movePickerPanelPosition(position: .tip, animated: false)
    }
    
    func movePickerPanelPosition(position: FloatingPanelPosition, animated: Bool, shouldAdjustMap: Bool = false)
    {
        self.pickerFloatingPanelController?.move(to: position, animated: animated)
        self.previousPanelPosition = position
    }
    
    func getTagForRouteInfoView() -> Int
    {
        if MapState.routeInfoShowing == .none
        {
            return DisplayConstants.helpInfoViewTag
        }
        return DisplayConstants.routeInfoPickerViewTag
    }
    
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return RouteInfoPickerFloatingPanelLayout()
    }
    
    func floatingPanelDidChangePosition(_ vc: FloatingPanelController) {
        if self.previousPanelPosition == vc.position
        {
            self.shouldNotAdjustMapForPanelMove = true
        }
        
        if vc.position == .tip
        {
            self.view.viewWithTag(getTagForRouteInfoView())?.alpha = 0.0
            NotificationCenter.default.post(name: NSNotification.Name("CollapseFilters"), object: self)
            
            if self.shouldNotAdjustMapForPanelMove
            {
                self.shouldNotAdjustMapForPanelMove = false
            }
            else
            {
                self.moveMapCenter(x: 0, y: DisplayConstants.panelTipSize-DisplayConstants.panelHalfSize)
            }
        }
        else
        {
            self.view.viewWithTag(getTagForRouteInfoView())?.alpha = 1.0
            if self.shouldNotAdjustMapForPanelMove
            {
                self.shouldNotAdjustMapForPanelMove = false
            }
            else
            {
                self.moveMapCenter(x: 0, y: DisplayConstants.panelHalfSize-DisplayConstants.panelTipSize)
            }
        }
        
        self.previousPanelPosition = vc.position
    }
    
    //var previousPanelYPos: CGFloat?
    
    func floatingPanelDidMove(_ vc: FloatingPanelController) {
        let y = vc.surfaceView.frame.origin.y
        let tipY = vc.originYOfSurface(for: .tip)
        if y > tipY - DisplayConstants.panelTipSize {
            let progress = max(0.0, min((tipY - y) / DisplayConstants.panelTipSize, 1.0))
            self.view.viewWithTag(getTagForRouteInfoView())?.alpha = progress
        }
        
//        if self.previousPanelYPos != nil && abs(previousPanelYPos!-y) > 5.0
//        {
//            self.moveMapCenter(x: 0, y: previousPanelYPos!-y)
//            self.previousPanelYPos = y
//        }
//        else if self.previousPanelYPos == nil
//        {
//            self.previousPanelYPos = y
//        }
    }
    
    func floatingPanelDidEndDragging(_ vc: FloatingPanelController, withVelocity velocity: CGPoint, targetPosition: FloatingPanelPosition) {
        if MapState.routeInfoShowing == .none { return }

        let progress = ((targetPosition == .tip) ? 0.0 : 1.0)
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .allowUserInteraction, animations: {
            self.view.viewWithTag(self.getTagForRouteInfoView())?.alpha = CGFloat(progress)
        }, completion: nil)
    }
    
    @objc func showPickerView(shouldAdjustMap: Bool = false)
    {
        MapState.showingPickerView = true
        
        //animated = pickerFloatingPanelController?.viewIfLoaded?.window != nil
        
        self.movePickerPanelPosition(position: .half, animated: true, shouldAdjustMap: shouldAdjustMap)
        self.view.viewWithTag(DisplayConstants.routeInfoPickerViewTag)?.isHidden = false
        self.view.viewWithTag(DisplayConstants.helpInfoViewTag)?.isHidden = true
    }
    
    @objc func hidePickerView()
    {
        NotificationCenter.default.post(name: NSNotification.Name("CollapseFilters"), object: self)
        
        MapState.showingPickerView = false
        self.movePickerPanelPosition(position: .tip, animated: false)
    }
    
    func showPickerHelpInfoView()
    {
        self.movePickerPanelPosition(position: .half, animated: true, shouldAdjustMap: false)
        self.view.viewWithTag(DisplayConstants.routeInfoPickerViewTag)?.isHidden = true
        self.view.viewWithTag(DisplayConstants.helpInfoViewTag)?.isHidden = false
    }
    
    //MARK: - Update Notifications
    
    func setupRouteMapUpdateNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(updateMap(notification:)), name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAllAnnotations), name: NSNotification.Name("ReloadAnnotations"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showPickerView), name: NSNotification.Name("ShowRouteInfoPickerView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hidePickerView), name: NSNotification.Name("HideRouteInfoPickerView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(predictionTimesFinishedRefreshing), name: NSNotification.Name("UpdateCountdownProgressBar"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setupPredictionRefreshTimer), name: NSNotification.Name("StartPredictionRefresh"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopPredictionRefreshTimer), name: NSNotification.Name("StopPredictionRefresh"), object: nil)
    }
    
    func removeRouteMapUpdateNotifications()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReloadAnnotations"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateCountdownProgressBar"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("StartPredictionRefresh"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("StopPredictionRefresh"), object: nil)
    }
    
    //MARK: - Location Centering
    
    func moveMapCenter(x: CGFloat, y: CGFloat)
    {
        var centerPoint = mainMapView.convert(mainMapView.region.center, toPointTo: self.view)
        centerPoint.x += x
        centerPoint.y += y/2
        
        let offset = (pickerFloatingPanelController?.position == .half) ? DisplayConstants.panelHalfSize : DisplayConstants.panelTipSize
        centerPoint.y -= offset/2
        
        let newCenterLocation = mainMapView.convert(centerPoint, toCoordinateFrom: self.view)
        
        centerMapOnLocation(location: CLLocation(latitude: newCenterLocation.latitude, longitude: newCenterLocation.longitude))
    }
    
    @IBAction func centerMapOnCurrentLocation()
    {
        guard let userLocation = mainMapView.userLocation.location else { return }
        centerMapOnLocation(location: userLocation)
    }
    
    @IBAction func centerMapOnCurrentStop()
    {
        if MapState.routeInfoShowing != .stop { return }
        guard let currentStop = MapState.getCurrentStop() else { return }
        
        let stopLocation = CLLocation(latitude: currentStop.latitude, longitude: currentStop.longitude)
        centerMapOnLocation(location: stopLocation)
    }
    
    @IBAction func centerMapOnSelectedVehicleButton()
    {
        if MapState.routeInfoShowing != .stop { return }
        guard let selectedVehicleID = MapState.selectedVehicleID else { return }
        guard let selectedVehicleCoordinate = self.busAnnotations[selectedVehicleID]?.annotation.coordinate else { return }
        
        centerMapOnLocation(location: CLLocation(latitude: selectedVehicleCoordinate.latitude, longitude: selectedVehicleCoordinate.longitude))
    }
    
    func zoomMapOnCurrentStop()
    {
        guard let currentDirection = MapState.getCurrentDirection() else { return }
        guard let currentStops = currentDirection.stops?.array as? [Stop] else { return }
        guard let currentStop = MapState.getCurrentStop() else { return }
        guard let stopIndex = currentStops.firstIndex(of: currentStop) else { return }
        
        var minStopIndex = stopIndex
        if stopIndex > 0
        {
            minStopIndex -= 1
        }
        var maxStopIndex = stopIndex
        if stopIndex < currentStops.count-1
        {
            maxStopIndex += 1
        }
        
        let currentStopSlice = Array<Stop>(currentStops[minStopIndex...maxStopIndex])
        let currentStopLocation = CLLocation(latitude: currentStop.latitude, longitude: currentStop.longitude)
        zoomMapOnStopArray(stops: currentStopSlice, zoomMargin: MapConstants.stopZoomMarginPercent, center: currentStopLocation, animated: true)
    }
    
    func zoomMapOnCurrentDirection()
    {
        guard let currentDirection = MapState.getCurrentDirection() else { return }
        guard let currentStops = currentDirection.stops?.array as? [Stop] else { return }
        
        zoomMapOnStopArray(stops: currentStops, zoomMargin: MapConstants.directionZoomMarginPercent)
    }
    
    func zoomMapOnStopArray(stops: [Stop], zoomMargin: Double, center: CLLocation? = nil, animated: Bool = false)
    {
        if stops.count == 0 { return }
        
        var minLat = stops[0].latitude
        var maxLat = stops[0].latitude
        var minLong = stops[0].longitude
        var maxLong = stops[0].longitude
        
        for stop in stops
        {
            minLat = min(minLat, stop.latitude)
            maxLat = max(maxLat, stop.latitude)
            minLong = min(minLong, stop.longitude)
            maxLong = max(maxLong, stop.longitude)
        }
        
        let centerLat = (minLat + maxLat)/2
        let centerLong = (minLong + maxLong)/2
        var centerLocation = CLLocation(latitude: centerLat, longitude: centerLong)
        if center != nil { centerLocation = center! }
        
        let latDegrees = maxLat - minLat
        let longDegrees = maxLong - minLong
        let span = MKCoordinateSpan(latitudeDelta: latDegrees, longitudeDelta: longDegrees)
        
        let latLongMaters = mapViewSpanToDistance(center: centerLocation.coordinate, span: span)
        let range = max(latLongMaters.latitude, latLongMaters.longitude)*(1+zoomMargin/100)
        
        centerMapOnLocation(location: centerLocation, range: range)
    }
    
    func centerMapOnLocation(location: CLLocation)
    {
        let mapRegionLatLong = mapViewSpanToDistance(center: mainMapView.region.center, span: mainMapView.region.span)
        
        centerMapOnLocation(location: location, range: min(mapRegionLatLong.latitude, mapRegionLatLong.longitude))
    }
    
    func mapViewSpanToDistance(center: CLLocationCoordinate2D, span: MKCoordinateSpan) -> (latitude: CLLocationDistance, longitude: CLLocationDistance)
    {
        let spanLatitudeDegrees = span.latitudeDelta
        let spanLongitudeDegrees = span.longitudeDelta
        
        let spanLatLocation = CLLocation(latitude: center.latitude + spanLatitudeDegrees, longitude: center.longitude)
        let spanLongLocation = CLLocation(latitude: center.latitude, longitude: center.longitude + spanLongitudeDegrees)
        
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        let latDistance = spanLatLocation.distance(from: centerLocation)
        let longDistance = spanLongLocation.distance(from: centerLocation)
        
        return (latDistance, longDistance)
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance, animated: Bool = true)
    {
        let prevMapRegion = mainMapView.region
        
        mainMapView.setRegion(MKCoordinateRegion(center: mainMapView.region.center, latitudinalMeters: range, longitudinalMeters: range), animated: false)
        
        let offset = (pickerFloatingPanelController?.position == .half) ? DisplayConstants.panelHalfSize : DisplayConstants.panelTipSize
        
        var point = mainMapView.convert(location.coordinate, toPointTo: self.view)
        point.y += offset/2
        let offsetCoordinate = mainMapView.convert(point, toCoordinateFrom: self.view)
        
        mainMapView.setRegion(prevMapRegion, animated: false)
        
        mainMapView.setRegion(MKCoordinateRegion(center: offsetCoordinate, latitudinalMeters: range, longitudinalMeters: range), animated: animated)
        
        showHideStopAnnotations(mapView: mainMapView, animated: false, range: range)
    }
    
    @objc func updateMap(notification: Notification?)
    {
        switch MapState.routeInfoShowing
        {
        case .none:
            resetAnnotations()
            
            hidePredictionNavigationBar()
                        
            (mainNavigationItem.titleView as? UILabel)?.text = "Map"
        case .direction:
            reloadAllAnnotations(fetchPredictions: true)
            
            OperationQueue.main.addOperation {
                self.zoomMapOnCurrentDirection()
            }
            
            if let direction = MapState.getCurrentDirection(), let location = self.mainMapView?.userLocation.location
            {
                let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: direction.stops!.array as! [Stop], locationToTest: location)
                MapState.selectedStopTag = sortedStops[0].tag!
                updateSelectedStopAnnotation(stopTag: sortedStops[0].tag!)
                
                bringSelectedStopHeaderToFront()
            }
            
            showPickerView()
            
            hidePredictionNavigationBar()
                        
            (mainNavigationItem.titleView as? UILabel)?.text = MapState.getCurrentDirection()?.route?.title
        case .stop:
            let changingRouteInfoShowing = notification?.userInfo?["ChangingRouteInfoShowing"] as? Bool ?? true
            
            if let stop = MapState.getCurrentStop()
            {
                let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                
                zoomMapOnCurrentStop()
                
                setAnnotationType(coordinate: selectedAnnotationLocation, annotationType: .small)
                setAnnotationType(coordinate: stopLocation.coordinate.convertToString(), annotationType: .large)
                
                reloadCurrentStopHeader(stopLocation: stopLocation)
                bringSelectedStopHeaderToFront()
                
                self.selectedAnnotationLocation = stopLocation.coordinate.convertToString()
            }
            
            predictionTimesLabel.text = ""
            showPredictionNavigationBar()
            refreshPredictionNavigationBar()
            
            if changingRouteInfoShowing
            {
                reloadPolyline()
            }
            
            showPickerView()
            
            (mainNavigationItem.titleView as? UILabel)?.text = MapState.getCurrentDirection()?.route?.title
        case .otherDirections:
            reloadAllAnnotations(fetchPredictions: true)
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            hidePredictionNavigationBar()
            
            (mainNavigationItem.titleView as? UILabel)?.text = MapState.getCurrentDirection()?.route?.title
        case .vehicles:
            reloadPredictionTimesLabel()
            
            (mainNavigationItem.titleView as? UILabel)?.text = MapState.getCurrentDirection()?.route?.title
            
            updateSelectedVehicle()
        }
    }
    
    //MARK: - Annotations
    
    @objc func reloadAllAnnotations(fetchPredictions: Bool)
    {
        resetAnnotations()
        
        if let direction = MapState.getCurrentDirection()
        {
            var stopOn = 0
            for stop in direction.stops!.array
            {
                let stop = stop as! Stop
                addAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude), stopTag: stop.tag!, endpointStop: (stopOn == 0 || stopOn == direction.stops!.array.count-1))
                stopOn += 1
            }
            
            reloadPolyline()
            
            if fetchPredictions
            {
                Task
                {
                    await fetchPredictionTimes()
                }
            }
        }
    }
    
    func addAnnotation(coordinate: CLLocationCoordinate2D, stopTag: String, annotationType: AnnotationType = .small, endpointStop: Bool = false)
    {
        let annotation = StopAnnotation(coordinate: coordinate, stopTag: stopTag, annotationType: annotationType, endpointStop: endpointStop)
        
        mainMapView.addAnnotation(annotation)
        stopAnnotations[CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).coordinate.convertToString()] = annotation
    }
    
    func setAnnotationType(coordinate: String?, annotationType: AnnotationType)
    {
        if coordinate != nil
        {
            if let annotation = stopAnnotations[coordinate!]
            {
                mainMapView.removeAnnotation(annotation)
                annotation.type = annotationType
                mainMapView.addAnnotation(annotation)
            }
        }
    }
    
    func resetAnnotations()
    {
        mainMapView.removeAnnotations(mainMapView.annotations)
        stopAnnotations.removeAll()
        busAnnotations.removeAll()
        vehicleIDs.removeAll()
        RouteDataManager.lastVehicleTime = nil
        
        if directionPolyline != nil
        {
            mainMapView.removeOverlay(directionPolyline!)
        }
        
        if borderPolyline != nil
        {
            mainMapView.removeOverlay(borderPolyline!)
        }
    }
    
    func reloadPolyline()
    {
        if directionPolyline != nil
        {
            mainMapView.removeOverlay(directionPolyline!)
        }
        
        if borderPolyline != nil
        {
            mainMapView.removeOverlay(borderPolyline!)
        }
        
        if let direction = MapState.getCurrentDirection()
        {
            var coordinates = Array<CLLocationCoordinate2D>()
            
            for stop in direction.stops!.array
            {
                if let stop = stop as? Stop
                {
                    coordinates.append(CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
                }
            }
            
            if (direction.route?.oppositeColor) != nil
            {
                let routeOppositeColor = UIColor(hexString: direction.route!.oppositeColor!)
                let showBorderPolyline = routeOppositeColor.hsba.b == 1 && appDelegate.getCurrentTheme() == .dark
                                
                if showBorderPolyline
                {
                    self.borderPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    mainMapView.addOverlay(borderPolyline!)
                }
            }
            
            self.directionPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mainMapView.addOverlay(directionPolyline!)
        }
    }
    
    func reloadCurrentStopHeader(stopLocation: CLLocation)
    {
        if selectedStopHeading != nil
        {
            self.mainMapView.removeAnnotation(selectedStopHeading!)
        }
        self.selectedStopHeading = SelectedStopHeadingAnnotation(coordinate: stopLocation.coordinate, heading: calculateCurrentStopHeading())
        self.mainMapView.addAnnotation(selectedStopHeading!)
    }
    
    func calculateCurrentStopHeading() -> CGFloat
    {
        if let stop = MapState.getCurrentStop(), let direction = MapState.getCurrentDirection(), let stopArray = direction.stops?.array as? [Stop], let stopIndex = stopArray.firstIndex(of: stop)
        {
            if stopIndex+1 < stopArray.count
            {
                let nextStopObject = stopArray[stopIndex+1]
                
                let nextStopCoordinate = CLLocationCoordinate2D(latitude: nextStopObject.latitude, longitude: nextStopObject.longitude)
                let currentStopCoordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                
                return CGFloat(currentStopCoordinate.heading(to: nextStopCoordinate))
            }
            else if stopArray.count >= 2
            {
                let prevStopObject = stopArray[stopIndex-1]
                
                let prevStopCoordinate = CLLocationCoordinate2D(latitude: prevStopObject.latitude, longitude: prevStopObject.longitude)
                let currentStopCoordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                
                return CGFloat(prevStopCoordinate.heading(to: currentStopCoordinate))
            }
        }
        
        return 0
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        
        if let polyline = overlay as? MKPolyline
        {
            if directionPolyline != nil && polyline == directionPolyline!
            {
                polylineRenderer.strokeColor = UIColor(red: 0.972, green: 0.611, blue: 0.266, alpha: 1)
                if let route = MapState.getCurrentDirection()?.route
                {
                    polylineRenderer.strokeColor = UIColor(hexString: route.color!)
                }
                polylineRenderer.lineWidth = MapConstants.directionPolylineWidth
            }
            else if borderPolyline != nil && polyline == borderPolyline!
            {
                polylineRenderer.strokeColor = UIColor(red: 0.972, green: 0.611, blue: 0.266, alpha: 1)
                if let route = MapState.getCurrentDirection()?.route
                {
                    polylineRenderer.strokeColor = UIColor(hexString: route.oppositeColor!)
                }
                polylineRenderer.lineWidth = MapConstants.borderPolylineWidth
            }
        }
        
        return polylineRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let stopAnnotation = annotation as? StopAnnotation
        {
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "StopAnnotation")
            
            switch stopAnnotation.type
            {
            case .small:
                annotationView.image = UIImage(named: "SmallDot")
            case .large:
                annotationView.image = UIImage(named: "BigDot")
            }
            
            if let route = MapState.getCurrentDirection()?.route
            {
                var brightness: CGFloat = 0.0
                UIColor(hexString: route.color!).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                
                if brightness > 0.6
                {
                    annotationView.image = annotationView.image?.colorized(color: UIColor(hexString: route.color!))
                }
            }
            
            if annotationView.gestureRecognizers == nil || annotationView.gestureRecognizers?.count == 0
            {
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openOtherDirectionsView(_:)))
                tapGesture.numberOfTapsRequired = 1
                annotationView.addGestureRecognizer(tapGesture)
            }
            
            return annotationView
        }
        else if annotation is BusAnnotation
        {
            if let annotationView = busAnnotations[(annotation as! BusAnnotation).id]?.annotationView
            {
                annotationView.annotation = annotation
                
                return annotationView
            }
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "BusAnnotation")
            
            annotationView.image = UIImage(named: "BusAnnotation")
            annotationView.centerOffset = CGPoint(x: 0, y: -annotationView.image!.size.height/2)
            
            (annotation as! BusAnnotation).headingAnnotation?.busAnnotationViewImageSize = annotationView.image?.size
            
            busAnnotations[(annotation as! BusAnnotation).id]?.annotationView = annotationView
            
            return annotationView
        }
        else if let headingAnnotation = annotation as? HeadingAnnotation
        {
            let headingImage = UIImage(named: "HeadingIndicator" + darkImageAppend())!
            let busImageSize = headingAnnotation.busAnnotationViewImageSize ?? UIImage(named: "BusAnnotation")!.size
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "HeadingAnnotation")
            annotationView.centerOffset = calculateOffsetForAnnotationView(busImageSize: busImageSize, headingImageSize: headingImage.size, headingValue: headingAnnotation.headingValue)
            annotationView.image = headingImage
            
            annotationView.transform = calculateHeadingDegreeShift(headingValue: headingAnnotation.headingValue)
            
            annotationView.isEnabled = false
            
            self.busAnnotations[headingAnnotation.id]?.headingAnnotationView = annotationView
            
            return annotationView
        }
        else if let selectedStopHeadingAnnotation = annotation as? SelectedStopHeadingAnnotation
        {
            let headingImage = UIImage(named: "SelectedStopHeading")!
            
            let dotImageSize = UIImage(named: "BigDot")!.size
            
            let xOffset = (dotImageSize.width/2+(headingImage.size.height/2)) * cos(CGFloat(selectedStopHeadingAnnotation.headingValue - 90).degreesToRadians)
            let yOffset = (dotImageSize.width/2+(headingImage.size.height/2)) * sin(CGFloat(selectedStopHeadingAnnotation.headingValue - 90).degreesToRadians)
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "SelectedStopHeadingAnnotation")
            annotationView.centerOffset = CGPoint(x: xOffset, y: yOffset)
            annotationView.image = headingImage
            
            var headingValueToRotateBy = selectedStopHeadingAnnotation.headingValue
            
            if let route = MapState.getCurrentDirection()?.route
            {
                var brightness: CGFloat = 0.0
                UIColor(hexString: route.color!).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                
                if brightness > 0.6
                {
                    annotationView.image = annotationView.image?.colorized(color: UIColor(hexString: route.color!))
                    
                    headingValueToRotateBy -= 180
                }
            }
            
            let t: CGAffineTransform = CGAffineTransform(rotationAngle: CGFloat(headingValueToRotateBy) * CGFloat.pi / 180)
            annotationView.transform = t
            
            annotationView.isEnabled = false
            
            return annotationView
        }
        else if annotation is MKUserLocation
        {
            return nil
        }
        
        return nil
    }
    
    func calculateOffsetForAnnotationView(busImageSize: CGSize, headingImageSize: CGSize, headingValue: Int) -> CGPoint
    {
        let xOffset = (busImageSize.width/2+(headingImageSize.height/2)*2) * cos(CGFloat(headingValue - 90).degreesToRadians)
        let yOffset = (busImageSize.width/2+(headingImageSize.height/2)*2) * sin(CGFloat(headingValue - 90).degreesToRadians)
        
        return CGPoint(x: xOffset, y: yOffset - busImageSize.height/2)
    }
    
    func calculateHeadingDegreeShift(headingValue: Int) -> CGAffineTransform
    {
        return CGAffineTransform(rotationAngle: CGFloat(headingValue) * CGFloat.pi / 180)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let busAnnotation = view.annotation as? BusAnnotation
        {
            busAnnotation.isMapKitSelected = true
            
            if MapState.selectedVehicleID != nil
            {
                busAnnotations[MapState.selectedVehicleID!]?.annotationView?.image = UIImage(named: "BusAnnotation")
            }
            
            MapState.selectedVehicleID = busAnnotation.id
            view.image = UIImage(named: "BusAnnotationDark")
            
            reloadPredictionTimesLabel()
        }
        else if let stopAnnotation = view.annotation as? StopAnnotation, MapState.routeInfoShowing == .stop && MapState.selectedStopTag != stopAnnotation.stopTag, !MapState.favoriteFilterEnabled
        {
            MapState.selectedStopTag = stopAnnotation.stopTag
            NotificationCenter.default.post(name: NSNotification.Name("SelectCurrentStop"), object: self)
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if let busAnnotation = view.annotation as? BusAnnotation
        {
            busAnnotation.isMapKitSelected = false
        }
    }
    
    func updateSelectedStopAnnotation(stopTag: String)
    {
        if let stop = RouteDataManager.fetchStop(stopTag: stopTag)
        {
            setAnnotationType(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude).convertToString(), annotationType: .large)
            
            reloadCurrentStopHeader(stopLocation: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
            
            bringSelectedStopHeaderToFront()
        }
    }
    
    func bringSelectedStopHeaderToFront()
    {
        if let selectedStopHeading = self.selectedStopHeading, let selectedStopHeadingView = mainMapView.view(for: selectedStopHeading)
        {
            selectedStopHeadingView.superview?.bringSubviewToFront(selectedStopHeadingView)
        }
    }
        
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        showHideStopAnnotations(mapView: mapView, animated: true)
    }
    
    func showHideStopAnnotations(mapView: MKMapView, animated: Bool = true, range: CLLocationDistance? = nil)
    {
        OperationQueue.main.addOperation {
            var longDistance = self.mapViewSpanToDistance(center: mapView.region.center, span: mapView.region.span).longitude
            if range != nil { longDistance = range! }
            let hideAnnotations = (longDistance >= (MapState.getCurrentDirection()?.route?.agency?.name == BARTAPI.BARTAgencyTag ? MapConstants.BARTMaxLongMetersBeforeHidingStopAnnotations : MapConstants.NextBusMaxLongMetersBeforeHidingStopAnnotations))
            
            let annotations = mapView.annotations
            for annotation in annotations
            {
                switch annotation.self
                {
                case is StopAnnotation:
                    if (annotation as! StopAnnotation).type == .small && !(annotation as! StopAnnotation).endpointStop
                    {
                        if animated
                        {
                            UIView.animate(withDuration: 0.1) {
                                mapView.view(for: annotation)?.isHidden = hideAnnotations
                            }
                        }
                        else
                        {
                            mapView.view(for: annotation)?.isHidden = hideAnnotations
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    //MARK: - Segue
    
    @IBAction func routesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showRoutesTableView", sender: self)
    }
    
    @IBAction func favoritesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showFavoritesTableView", sender: self)
    }
    
    @IBAction func nearbyButtonPressed(_ sender: Any) {
        self.locationToUse = self.mainMapView.userLocation.location
        self.performSegue(withIdentifier: "showNearbyStopTableView", sender: self)
    }
    
    @IBAction func historyButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showRecentStopTableView", sender: self)
    }
    
    @objc func openOtherDirectionsView(_ sender: UIGestureRecognizer)
    {
        let annotationStopTag = ((sender.view as? MKAnnotationView)?.annotation as? StopAnnotation)?.stopTag
        
        if MapState.selectedStopTag != annotationStopTag
        {
            return
        }
        
        MapState.selectedStopTag = annotationStopTag
        if let selectedStop = MapState.getCurrentStop()
        {
            MapState.routeInfoObject = selectedStop.direction?.allObjects
            self.performSegue(withIdentifier: "showOtherDirectionsTableView", sender: self)
        }
    }
    
    var locationToUse: CLLocation?
    @objc func openNearbyStopViewFromSelectedStop(_ sender: Any)
    {
        if let currentStop = MapState.getCurrentStop()
        {
            let latitude = currentStop.latitude
            let longitude = currentStop.longitude
            self.locationToUse = CLLocation(latitude: latitude, longitude: longitude)
            self.performSegue(withIdentifier: "showNearToStopTableView", sender: self)
        }
    }
    
    var newStopNotificationID: NSManagedObjectID?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier
        {
            case "showRoutesTableView", "showFavoritesTableView", "showNearbyStopTableView", "showRecentStopTableView":
            break
            
            default:
            self.stopPredictionRefreshTimer()
        }
        
        if segue.identifier == "showRecentStopTableView"
        {
            let stopsTableView = segue.destination as! StopsTableViewController
            stopsTableView.stopFetchType = .recent
        }
        else if segue.identifier == "showNearbyStopTableView" || segue.identifier == "showNearToStopTableView"
        {
            let stopsTableView = segue.destination as! StopsTableViewController
            stopsTableView.stopFetchType = .nearby
            stopsTableView.locationToFetchFrom = locationToUse
        }
        else if segue.identifier == "openNewNotificationEditor"
        {
            let notificationEditorView = segue.destination as! NotificationEditorViewController
            
            guard let newStopNotificationID = newStopNotificationID else { return }
            notificationEditorView.stopNotificationID = newStopNotificationID
            notificationEditorView.newNotification = true
        }
    }
    
    @IBAction func unwindFromRouteTableViewWithSelectedRoute(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromRouteTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindWithSelectedStop(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations(fetchPredictions: false)
        NotificationCenter.default.post(name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromFavoritesView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromSettingsView(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations(fetchPredictions: false)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromOtherDirectionsView(_ segue: UIStoryboardSegue)
    {
        MapState.routeInfoObject = MapState.getCurrentDirection()
        showPickerView()
    }
    
    @IBAction func unwindFromStopsTableViewWithSelectedStop(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations(fetchPredictions: false)
        NotificationCenter.default.post(name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromFavoritesViewWithSelectedRoute(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations(fetchPredictions: false)
        NotificationCenter.default.post(name: NSNotification.Name("EnableFilters"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromStopTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromStopNotificationTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    //MARK: - Bus Predications
    
    func showPredictionNavigationBar()
    {
        OperationQueue.main.addOperation {
            self.predictionBarTopConstraint.constant = 0
            
            self.predictionTimesNavigationBar.isHidden = false
            self.vehicleSelectionButton.isEnabled = true
            self.vehicleSelectionButton.isHidden = false
            
            self.centerOnStopButton.isHidden = false
            self.centerOnStopButton.isEnabled = true
            
            UIView.animate(withDuration: 0.5) {
                self.view.layoutSubviews()
            }
            
            self.setupPredictionRefreshTimer()
        }
    }
    
    var predictionNavigationBarShowing: Bool
    {
        return !self.predictionTimesNavigationBar.isHidden
    }
    
    @objc func setupPredictionRefreshTimer()
    {
        if predictionRefreshTimer?.isValid ?? false { return }
        
        let refreshTime = UserDefaults.standard.object(forKey: "PredictionRefreshTime") as? TimeInterval ?? 60.0
        
        if refreshTime > 0.0
        {
            self.predictionRefreshTimer?.invalidate()
            self.predictionRefreshTimer = Timer.scheduledTimer(timeInterval: refreshTime, target: self, selector: #selector(self.refreshPredictionNavigationBar), userInfo: nil, repeats: true)
        }
    }
    
    @objc func stopPredictionRefreshTimer()
    {
        self.predictionRefreshTimer?.invalidate()
    }
    
    func hidePredictionNavigationBar()
    {
        OperationQueue.main.addOperation {
            self.centerOnStopButton.isHidden = true
            self.centerOnStopButton.isEnabled = false
            
            self.centerOnVehicleButton.isHidden = true
            self.centerOnVehicleButton.isEnabled = false
            
            self.predictionBarTopConstraint.constant = -1*(self.predictionTimesNavigationBar.frame.size.height)
            
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutSubviews()
            }) { (bool) in
                self.predictionTimesNavigationBar.isHidden = true
                self.vehicleSelectionButton.isEnabled = false
                self.vehicleSelectionButton.isHidden = true
                self.predictionTimesProgressView.isHidden = true
            }
                        
            self.stopPredictionRefreshTimer()
            self.activityIndicator.stopAnimating()
        }
    }
    
    @objc @IBAction func refreshPredictionNavigationBar()
    {
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.layer.sublayers?.forEach { $0.removeAllAnimations() }
            self.predictionTimesProgressView.setProgress(0, animated: false)
            self.predictionTimesProgressView.tintColor = UIColor.systemGreen
            self.predictionTimesProgressView.isHidden = false
            self.predictionTimesProgressViewConstraint.constant = 0
            
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutSubviews()
            })
        }
        
        Task
        {
            await fetchPredictionTimes()
        }
    }
    
    func fetchPredictionTimes() async
    {
        self.stopPredictionRefreshTimer()
        
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(0.25, animated: true)
            
            self.refreshButton.isEnabled = false
            self.predictionTimesNavigationBar.topItem?.leftBarButtonItem = nil
            
            if self.predictionNavigationBarShowing
            {
                self.activityIndicator.startAnimating()
            }
        }
        
//        let predictionTimesReturnUUID = UUID().uuidString
//        NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTimes(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
//        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: MapState.getCurrentStop(), direction: MapState.getCurrentDirection())
        
        let previousDirectionStopID = MapState.selectedDirectionStopID
        
        let predictionsFetchResult = await RouteDataManager.fetchPredictionTimesForStop(stop: MapState.getCurrentStop(), direction: MapState.getCurrentDirection())
        
        var isCorrectDirectionStopID = true
        if let currentDirectionTag = MapState.getCurrentDirection()?.tag, let currentStopTag = MapState.getCurrentStop()?.tag
        {
            isCorrectDirectionStopID = previousDirectionStopID == (currentStopTag + "-" + currentDirectionTag)
        }
        if !isCorrectDirectionStopID { return }
        
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(0.5, animated: true)
        }
        
        switch predictionsFetchResult
        {
        case .success(let predictions):
            let vehicleIDs = predictions.map({ prediction in
                return prediction.vehicleID ?? ""
            })
            if vehicleIDs.count > 0
            {
                self.vehicleIDs = vehicleIDs
            }
            
            reloadPredictionTimesLabel()
            
            if vehicleIDs.count > 0
            {
                OperationQueue.main.addOperation {
                    self.predictionTimesProgressView.setProgress(0.75, animated: true)
                }
                
                await fetchVehicleLocations(vehicleIDs: vehicleIDs)
            }
            
            OperationQueue.main.addOperation {
                self.predictionTimesFinishedRefreshing()
            }
            break
        case .error(let reason):
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = reason
                self.predictionTimesFinishedRefreshing()
            }
        }
        
//        if let predictions = notification.userInfo!["predictions"] as? Array<PredictionTime>
//        {
//            self.predictions = predictions
//
//            let vehicleIDs = predictions.map({ prediction in
//                return prediction.vehicleID ?? ""
//            })
//            if vehicleIDs.count > 0
//            {
//                self.vehicleIDs = vehicleIDs
//            }
//
//            reloadPredictionTimesLabel()
//
//            if willLoadSchedule { return }
//
//            if vehicleIDs.count > 0
//            {
//                NotificationCenter.default.post(name: NSNotification.Name("FetchVehicleLocations"), object: nil)
//            }
//            else
//            {
//                OperationQueue.main.addOperation {
//                    self.predictionTimesFinishedRefreshing()
//                }
//            }
//        }
//        else if let error = notification.userInfo!["error"] as? String
//        {
//            OperationQueue.main.addOperation {
//                self.predictionTimesLabel.text = error
//                self.predictionTimesFinishedRefreshing()
//            }
//        }
    }
    
    func fetchVehicleLocations(vehicleIDs: [String]) async
    {
        let previousDirectionTag = MapState.selectedDirectionTag
        
        let vehicleLocationsFetchResult = await RouteDataManager.fetchVehicleLocations(vehicleIDs: vehicleIDs, direction: MapState.getCurrentDirection())
        
        if (previousDirectionTag != MapState.selectedDirectionTag) { return }
        
        switch vehicleLocationsFetchResult
        {
        case .success(let vehicleLocations):
            OperationQueue.main.addOperation {
                var annotationsToSave = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?, headingAnnotationView: MKAnnotationView?)>()
                
                for vehicleLocation in vehicleLocations
                {
                    let locationCoordinate = CLLocationCoordinate2D(latitude: vehicleLocation.latitude, longitude: vehicleLocation.longitude)
                    
                    if let busAnnotationTuple = self.busAnnotations[vehicleLocation.vehicleID]
                    {
                        UIView.animate(withDuration: 1, animations: {
                            busAnnotationTuple.annotation.coordinate = locationCoordinate
                        })
                        if let heading = vehicleLocation.heading
                        {
                            busAnnotationTuple.annotation.heading = heading
                        }
                    }
                    else
                    {
                        self.busAnnotations[vehicleLocation.vehicleID] = (annotation: BusAnnotation(coordinate: locationCoordinate, heading: vehicleLocation.heading ?? 0, id: vehicleLocation.vehicleID), annotationView: nil, headingAnnotationView: nil)
                    }
                    
                    if let annotationView = self.busAnnotations[vehicleLocation.vehicleID]?.annotationView
                    {
                        annotationView.annotation = self.busAnnotations[vehicleLocation.vehicleID]!.annotation
                    }
                    else
                    {
                        self.mainMapView.addAnnotation(self.busAnnotations[vehicleLocation.vehicleID]!.annotation)
                    }
                    
                    if let headingAnnotation = self.busAnnotations[vehicleLocation.vehicleID]!.annotation.headingAnnotation
                    {
                        UIView.animate(withDuration: 1, animations: {
                            headingAnnotation.coordinate = locationCoordinate
                        })
                        if let heading = vehicleLocation.heading
                        {
                            headingAnnotation.headingValue = heading
                        }
                        
                        if let headingAnnotationView = self.busAnnotations[vehicleLocation.vehicleID]!.headingAnnotationView
                        {
                            let headingImage = UIImage(named: "HeadingIndicator" + self.darkImageAppend())!
                            let busImageSize = headingAnnotation.busAnnotationViewImageSize ?? UIImage(named: "BusAnnotation")!.size
                            
                            UIView.animate(withDuration: 1, animations: {
                                headingAnnotationView.centerOffset = CGPoint(x: 0, y: 0)
                                headingAnnotationView.centerOffset = self.calculateOffsetForAnnotationView(busImageSize: busImageSize, headingImageSize: headingImage.size, headingValue: headingAnnotation.headingValue)
                                headingAnnotationView.transform = self.calculateHeadingDegreeShift(headingValue: headingAnnotation.headingValue)
                            })
                        }
                    }
                    else
                    {
                        let headingAnnotation = HeadingAnnotation(coordinate: locationCoordinate, heading: vehicleLocation.heading ?? 0, id: vehicleLocation.vehicleID)
                        self.mainMapView.addAnnotation(headingAnnotation)
                        
                        self.busAnnotations[vehicleLocation.vehicleID]?.annotation.headingAnnotation = headingAnnotation
                    }
                    
                    annotationsToSave[vehicleLocation.vehicleID] = self.busAnnotations[vehicleLocation.vehicleID]
                }
                
                for annotation in annotationsToSave
                {
                    self.busAnnotations.removeValue(forKey: annotation.key)
                }
                
                for annotation in self.busAnnotations
                {
                    self.mainMapView.removeAnnotation(annotation.value.annotation)
                    if let headingAnnotation = annotation.value.annotation.headingAnnotation
                    {
                        self.mainMapView.removeAnnotation(headingAnnotation)
                    }
                }
                
                self.busAnnotations = annotationsToSave
            }
            break
        case .error:
            break
        }
    }
    
    @objc func receivePredictionTimes(_ notification: Notification)
    {
        var isCorrectDirectionStopID = true
        if let notificationDirectionStopID = notification.userInfo!["directionStopID"] as? String, let currentDirectionTag = MapState.getCurrentDirection()?.tag, let currentStopTag = MapState.getCurrentStop()?.tag
        {
            isCorrectDirectionStopID = notificationDirectionStopID == currentStopTag + "-" + currentDirectionTag
        }
        if !isCorrectDirectionStopID
        {
            NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
            return
        }
        
        let willLoadSchedule = notification.userInfo!["willLoadSchedule"] as? Bool ?? false
        
        if !willLoadSchedule
        {
            NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
            
            OperationQueue.main.addOperation {
                self.refreshButton.isEnabled = true
                self.predictionTimesNavigationBar.topItem?.leftBarButtonItem = self.refreshButton
                
                self.activityIndicator.stopAnimating()
            }
        }
        else
        {
            OperationQueue.main.addOperation {
                self.predictionTimesProgressView.setProgress(0.5, animated: true)
            }
        }
        
        if let predictions = notification.userInfo!["predictions"] as? Array<PredictionTime>
        {
            self.predictions = predictions
            
            let vehicleIDs = predictions.map({ prediction in
                return prediction.vehicleID ?? ""
            })
            if vehicleIDs.count > 0
            {
                self.vehicleIDs = vehicleIDs
            }
            
            reloadPredictionTimesLabel()
            
            if willLoadSchedule { return }
            
            if vehicleIDs.count > 0
            {
                NotificationCenter.default.post(name: NSNotification.Name("FetchVehicleLocations"), object: nil)
            }
            else
            {
                OperationQueue.main.addOperation {
                    self.predictionTimesFinishedRefreshing()
                }
            }
        }
        else if let error = notification.userInfo!["error"] as? String
        {
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = error
                self.predictionTimesFinishedRefreshing()
            }
        }
    }
    
    func reloadPredictionTimesLabel()
    {
        let formattedPredictionsString = RouteDataManager.formatPredictions(predictions: self.predictions)
        
        OperationQueue.main.addOperation {
            self.predictionTimesLabel.attributedText = formattedPredictionsString
            
            if MapState.selectedVehicleID != nil && self.vehicleIDs.contains(MapState.selectedVehicleID!)
            {
                self.centerOnVehicleButton.alpha = 0
                self.centerOnVehicleButton.isHidden = false
                self.centerOnVehicleButton.isEnabled = true
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.centerOnVehicleButton.alpha = 1
                })
            }
            else
            {
                UIView.animate(withDuration: 0.2, animations: {
                    self.centerOnVehicleButton.alpha = 0
                }, completion: { (bool) in
                    self.centerOnVehicleButton.isHidden = false
                    self.centerOnVehicleButton.isEnabled = true
                })
            }
        }
    }
    
    @objc func receiveVehicleLocations(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        if let notificationDirection = notification.userInfo!["direction"] as? String, let currentDirectionTag = MapState.getCurrentDirection()?.tag, notificationDirection != currentDirectionTag
        {
            return
        }
        
        OperationQueue.main.addOperation {
            self.predictionTimesFinishedRefreshing()
            
            var annotationsToSave = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?, headingAnnotationView: MKAnnotationView?)>()
            
            let vehicleLocations = notification.userInfo!["vehicleLocations"] as! Array<(id: String, location: CLLocation, heading: Int)>
            for vehicleLocation in vehicleLocations
            {
                if let busAnnotationTuple = self.busAnnotations[vehicleLocation.id]
                {
                    UIView.animate(withDuration: 1, animations: {
                        busAnnotationTuple.annotation.coordinate = vehicleLocation.location.coordinate
                    })
                    busAnnotationTuple.annotation.heading = vehicleLocation.heading
                }
                else
                {
                    self.busAnnotations[vehicleLocation.id] = (annotation: BusAnnotation(coordinate: vehicleLocation.location.coordinate, heading: vehicleLocation.heading, id: vehicleLocation.id), annotationView: nil, headingAnnotationView: nil)
                }
                
                if let annotationView = self.busAnnotations[vehicleLocation.id]?.annotationView
                {
                    annotationView.annotation = self.busAnnotations[vehicleLocation.id]!.annotation
                }
                else
                {
                    self.mainMapView.addAnnotation(self.busAnnotations[vehicleLocation.id]!.annotation)
                }
                
                if let headingAnnotation = self.busAnnotations[vehicleLocation.id]!.annotation.headingAnnotation
                {
                    UIView.animate(withDuration: 1, animations: {
                        headingAnnotation.coordinate = vehicleLocation.location.coordinate
                    })
                    headingAnnotation.headingValue = vehicleLocation.heading
                    
                    if let headingAnnotationView = self.busAnnotations[vehicleLocation.id]!.headingAnnotationView
                    {
                        let headingImage = UIImage(named: "HeadingIndicator" + self.darkImageAppend())!
                        let busImageSize = headingAnnotation.busAnnotationViewImageSize ?? UIImage(named: "BusAnnotation")!.size
                        
                        UIView.animate(withDuration: 1, animations: {
                            headingAnnotationView.centerOffset = CGPoint(x: 0, y: 0)
                            headingAnnotationView.centerOffset = self.calculateOffsetForAnnotationView(busImageSize: busImageSize, headingImageSize: headingImage.size, headingValue: headingAnnotation.headingValue)
                            headingAnnotationView.transform = self.calculateHeadingDegreeShift(headingValue: headingAnnotation.headingValue)
                        })
                    }
                }
                else
                {
                    let headingAnnotation = HeadingAnnotation(coordinate: vehicleLocation.location.coordinate, heading: vehicleLocation.heading, id: vehicleLocation.id)
                    self.mainMapView.addAnnotation(headingAnnotation)
                    
                    self.busAnnotations[vehicleLocation.id]?.annotation.headingAnnotation = headingAnnotation
                }
                
                annotationsToSave[vehicleLocation.id] = self.busAnnotations[vehicleLocation.id]
            }
            
            for annotation in annotationsToSave
            {
                self.busAnnotations.removeValue(forKey: annotation.key)
            }
            
            for annotation in self.busAnnotations
            {
                self.mainMapView.removeAnnotation(annotation.value.annotation)
                if let headingAnnotation = annotation.value.annotation.headingAnnotation
                {
                    self.mainMapView.removeAnnotation(headingAnnotation)
                }
            }
            
            self.busAnnotations = annotationsToSave
        }
    }
    
    @objc func predictionTimesFinishedRefreshing()
    {
        self.refreshButton.isEnabled = true
        self.predictionTimesNavigationBar.topItem?.leftBarButtonItem = self.refreshButton
        
        self.activityIndicator.stopAnimating()
        
        if MapState.routeInfoShowing != .stop { return }
        
        setupPredictionRefreshTimer()
        
        if self.predictionTimesProgressView.isHidden || self.currentlyAnimatingPredictionTimesProgressView { return }
        currentlyAnimatingPredictionTimesProgressView = true
        
        self.predictionTimesProgressView.setProgress(1, animated: true)
        
        let shouldShowRefreshTimeOnPredictionTimesProgressView = true
        
        if shouldShowRefreshTimeOnPredictionTimesProgressView, let nextPredictionRefreshTime = self.predictionRefreshTimer?.fireDate
        {
            self.predictionTimesProgressView.tintColor = UIColor.systemBlue
            UIView.animate(withDuration: 0.5, animations: {
                self.predictionTimesProgressView.layoutIfNeeded()
            })
            
            let timeLeftToPredictionRefresh = nextPredictionRefreshTime.timeIntervalSince1970-Date().timeIntervalSince1970
            
            self.predictionTimesProgressView.setProgress(0.001, animated: false)
            UIView.animate(withDuration: timeLeftToPredictionRefresh, delay: 0, options: [.curveLinear]) {
                self.predictionTimesProgressView.layoutIfNeeded()
            } completion: { complete in
                self.currentlyAnimatingPredictionTimesProgressView = false
            }
        }
        else
        {
            self.hidePredictionTimesProgressView()
        }
    }
    
    func hidePredictionTimesProgressView()
    {
        self.predictionTimesProgressViewConstraint.constant = -self.predictionTimesProgressView.frame.size.height
        
        UIView.animate(withDuration: 0.75, animations: {
            self.view.layoutSubviews()
        }) { (bool) in
            self.predictionTimesProgressView.isHidden = true
        }
    }
    
    //MARK: - Vehicles Menu
    
    func toggleVehiclesMenu() {
        if MapState.routeInfoShowing != .vehicles && vehicleIDs.count == predictions.count
        {
            var predictionVehicleArray = Array<(vehicleID: String, prediction: String)>()
            
            var vehicleOn = 0
            while vehicleOn < vehicleIDs.count
            {
                predictionVehicleArray.append((vehicleID: vehicleIDs[vehicleOn], prediction: predictions[vehicleOn].time))
                vehicleOn += 1
            }
            
            MapState.routeInfoObject = predictionVehicleArray
            MapState.routeInfoShowing = .vehicles
            
            showPickerView(shouldAdjustMap: true)
        }
        else if MapState.routeInfoShowing == .vehicles
        {
            MapState.routeInfoObject = MapState.getCurrentDirection()
            MapState.routeInfoShowing = .stop
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    func selectClosestVehicle() {
        if vehicleIDs.count < 1 { return }
        
        var vehicleIndexToSelect = 0
        
        if let selectedVehicleID = MapState.selectedVehicleID, var selectedVehicleIndex = vehicleIDs.firstIndex(of: selectedVehicleID)
        {
            if selectedVehicleIndex != 0 && selectedVehicleIndex < vehicleIDs.count-1
            {
                selectedVehicleIndex += 1
            }
            else
            {
                selectedVehicleIndex = -1
            }
            
            vehicleIndexToSelect = selectedVehicleIndex
        }
        else
        {
            vehicleIndexToSelect = 0
        }
        
        if vehicleIndexToSelect == -1
        {
            updateSelectedVehicle()
            MapState.selectedVehicleID = nil
        }
        else
        {
            MapState.selectedVehicleID = vehicleIDs[vehicleIndexToSelect]
            updateSelectedVehicle()
        }
        
        reloadPredictionTimesLabel()
    }
    
    func updateSelectedVehicle()
    {
        let darkBusIcon = UIImage(named: "BusAnnotationDark")
        for busAnnotation in busAnnotations
        {
            if busAnnotation.value.annotationView?.image == darkBusIcon
            {
                busAnnotation.value.annotationView?.image = UIImage(named: "BusAnnotation")
            }
            
            if busAnnotation.value.annotation.isMapKitSelected && MapState.selectedVehicleID != nil
            {
                mainMapView.deselectAnnotation(busAnnotations[MapState.selectedVehicleID!]?.annotation, animated: false)
            }
        }
        
        busAnnotations[MapState.selectedVehicleID ?? ""]?.annotationView?.image = UIImage(named: "BusAnnotationDark")
    }
    
    @IBAction func vehiclesButtonSingleTap(_ sender: Any) {
        if MapState.routeInfoShowing == .vehicles
        {
            toggleVehiclesMenu()
        }
        else if MapState.routeInfoShowing == .stop
        {
            selectClosestVehicle()
        }
    }
    
    @IBAction func vehiclesButtonDoubleTap(_ sender: Any) {
        toggleVehiclesMenu()
    }
}

class StopAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var type: AnnotationType = .small
    var stopTag: String?
    var endpointStop: Bool = false
    
    init(coordinate: CLLocationCoordinate2D, stopTag: String, annotationType: AnnotationType = .small, endpointStop: Bool = false)
    {
        self.coordinate = coordinate
        self.type = annotationType
        self.stopTag = stopTag
        self.endpointStop = endpointStop
    }
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, annotationType: AnnotationType = .small, endpointStop: Bool = false)
    {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = annotationType
        self.endpointStop = endpointStop
    }
}

class BusAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    var heading: Int
    var id: String
    var title: String?
    var subtitle: String?
    var headingAnnotation: HeadingAnnotation?
    var isMapKitSelected = false
    
    init(coordinate: CLLocationCoordinate2D, heading: Int, id: String)
    {
        self.coordinate = coordinate
        self.heading = heading
        self.id = id
    }
}

class HeadingAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    var headingValue: Int
    var title: String?
    var subtitle: String?
    var busAnnotationViewImageSize: CGSize?
    var id: String
    
    init(coordinate: CLLocationCoordinate2D, heading: Int, id: String)
    {
        self.coordinate = coordinate
        self.headingValue = heading
        self.id = id
    }
}

class SelectedStopHeadingAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    var headingValue: CGFloat
    
    init(coordinate: CLLocationCoordinate2D, heading: CGFloat)
    {
        self.coordinate = coordinate
        self.headingValue = heading
    }
}

class RouteInfoPickerFloatingPanelLayout: FloatingPanelIntrinsicLayout {
    var initialPosition: FloatingPanelPosition {
        return .tip
    }
    
    var supportedPositions: Set<FloatingPanelPosition> {
        return [.tip, .half]
    }

    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
            case .half: return DisplayConstants.panelHalfSize
            case .tip: return DisplayConstants.panelTipSize
            default: return nil
        }
    }
    
    var positionReference: FloatingPanelLayoutReference {
        return .fromSafeArea
    }
}

class RouteInfoPickerTipFloatingPanelLayout: RouteInfoPickerFloatingPanelLayout
{
    override var supportedPositions: Set<FloatingPanelPosition> {
        return [.tip]
    }
}
