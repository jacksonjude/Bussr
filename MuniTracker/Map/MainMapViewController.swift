//
//  MainMapViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import MapKit
import FloatingPanel

let appDelegate = UIApplication.shared.delegate as! AppDelegate
let panelTipSize: CGFloat = 80.0
let panelHalfSize: CGFloat = 281.0
let panelBottomMargin: CGFloat = 5.0

enum AnnotationType
{
    case red
    case orange
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

/*extension Dictionary.Keys
{
    var array: [Key] {
        var keyArray = Array<Key>()
        for key in self
        {
            keyArray.append(key)
        }
        return keyArray
    }
}

extension Dictionary.Values
{
    var array: [Value] {
        var valueArray = Array<Value>()
        for value in self
        {
            valueArray.append(value)
        }
        return valueArray
    }
}

extension Dictionary
{
    mutating func setKeysValues(keys: [Key], values: [Value])
    {
        var numOn = 0
        for key in keys
        {
            self[key] = values[numOn]
            numOn += 1
        }
    }
}*/

class MainMapViewController: UIViewController, MKMapViewDelegate, FloatingPanelControllerDelegate {
    
    @IBOutlet weak var mainMapView: MKMapView!
    @IBOutlet weak var predictionTimesNavigationBar: UINavigationBar!
    @IBOutlet weak var predictionTimesLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var vehicleSelectionButton: UIButton!
    //@IBOutlet weak var pickerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var predictionBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var predictionTimesProgressView: UIProgressView!
    @IBOutlet weak var predictionTimesProgressViewConstraint: NSLayoutConstraint!
    
    //37.773972
    //37.738802
    let initialLocation = CLLocation(latitude: 37.773972, longitude: -122.438765)
    
    var downloadAllData = false
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    
    var selectedAnnotationLocation: String?
    var stopAnnotations = Dictionary<String,StopAnnotation>()
    var directionPolyline: MKPolyline?
    var busAnnotations = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?, headingAnnotationView: MKAnnotationView?)>()
    var vehicleIDs = Array<String>()
    var predictions = Array<String>()
    var selectedStopHeading: SelectedStopHeadingAnnotation?
    
    var locationManager = CLLocationManager()
    
    var predictionRefreshTimer: Timer?
    
    //MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        mainMapView.showsUserLocation = true
        mainMapView.isRotateEnabled = false
        centerMapOnLocation(location: initialLocation, range: 15000)
        
        setupRouteMapUpdateNotifications()
                
        setupPickerPanel()
        
        if appDelegate.firstLaunch
        {
            downloadAllData = true
        }
        
        setupThemeElements()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        
        setupThemeElements()
        reloadAllAnnotations() //For header annotation update
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.activityIndicator.style = .gray
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
            self.predictionTimesLabel.textColor = UIColor.black
        case .dark:
            self.activityIndicator.style = .white
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
            self.predictionTimesLabel.textColor = UIColor.white
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if downloadAllData
        {
            progressAlertView = UIAlertController(title: "Updating", message: "Updating route data...\n", preferredStyle: .alert)
            
            self.present(progressAlertView!, animated: true, completion: {
                let margin: CGFloat = 8.0
                let rect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
                self.progressView = UIProgressView(frame: rect)
                self.progressView!.tintColor = UIColor.blue
                self.progressAlertView!.view.addSubview(self.progressView!)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.addToProgress(notification:)), name: NSNotification.Name("CompletedRoute"), object: nil)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.dismissAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
                
                DispatchQueue.global(qos: .background).async
                    {
                        RouteDataManager.updateAllData()
                }
            })
            
            downloadAllData = false
        }
        
        setupThemeElements()
        
        if MapState.routeInfoShowing == .stop
        {
            self.setupPredictionRefreshTimer()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        self.predictionRefreshTimer?.invalidate()
    }
    
    //MARK: - Update Routes
    
    @objc func addToProgress(notification: Notification)
    {
        OperationQueue.main.addOperation {
            self.progressView?.progress = notification.userInfo?["progress"] as? Float ?? 0.0
        }
    }
    
    @objc func dismissAlertView()
    {
        progressAlertView?.dismiss(animated: true, completion: {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CompletedRoute"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            if appDelegate.firstLaunch && CLLocationManager.authorizationStatus() != .denied
            {
                self.locationManager.requestWhenInUseAuthorization()
            }
        })
    }
    
    //MARK: - Picker View Show/Hide
    
    var pickerFloatingPanelController: FloatingPanelController?
    
    func setupPickerPanel()
    {
        self.pickerFloatingPanelController = FloatingPanelController()
        
        pickerFloatingPanelController?.delegate = self
        
        let pickerContentVC = storyboard!.instantiateViewController(withIdentifier: "RouteInfoPickerViewController") as! RouteInfoPickerViewController
        pickerContentVC.mainMapViewController = self
        
        pickerFloatingPanelController?.set(contentViewController: pickerContentVC)
        
        pickerFloatingPanelController?.addPanel(toParent: self)
        pickerFloatingPanelController?.updateLayout()
        
        self.view.viewWithTag(618)?.isHidden = true
        
        pickerFloatingPanelController?.move(to: .tip, animated: false)
    }
    
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        if MapState.routeInfoShowing == .none
        {
            return RouteInfoPickerTipFloatingPanelLayout()
        }
        else
        {
            return RouteInfoPickerFloatingPanelLayout()
        }
    }
    
    func floatingPanelDidChangePosition(_ vc: FloatingPanelController) {
        if vc.position == .tip
        {
            self.view.viewWithTag(618)?.alpha = 0.0
            NotificationCenter.default.post(name: NSNotification.Name("CollapseFilters"), object: self)
        }
        else
        {
            self.view.viewWithTag(618)?.alpha = 1.0
        }
    }
    
    func floatingPanelDidMove(_ vc: FloatingPanelController) {
        if MapState.routeInfoShowing == .none { return }

        let y = vc.surfaceView.frame.origin.y
        let tipY = vc.originYOfSurface(for: .tip)
        if y > tipY - panelTipSize {
            let progress = max(0.0, min((tipY  - y) / panelTipSize, 1.0))
            self.view.viewWithTag(618)?.alpha = progress
        }
    }
    
    func floatingPanelDidEndDragging(_ vc: FloatingPanelController, withVelocity velocity: CGPoint, targetPosition: FloatingPanelPosition) {
        if MapState.routeInfoShowing == .none { return }

        let progress = ((targetPosition == .tip) ? 0.0 : 1.0)
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .allowUserInteraction, animations: {
            self.view.viewWithTag(618)?.alpha = CGFloat(progress)
        }, completion: nil)
    }
    
    @objc func showPickerView()
    {
        MapState.showingPickerView = true
        pickerFloatingPanelController?.updateLayout()
        self.pickerFloatingPanelController?.move(to: .half, animated: false)
        self.view.viewWithTag(618)?.isHidden = false
        
        NotificationCenter.default.post(name: NSNotification.Name("RouteInfoPickerViewShown"), object: nil)
    }
    
    @objc func hidePickerView()
    {
        NotificationCenter.default.post(name: NSNotification.Name("CollapseFilters"), object: self)
        
        MapState.showingPickerView = false
        self.pickerFloatingPanelController?.move(to: .tip, animated: false)
        
        
        NotificationCenter.default.post(name: NSNotification.Name("RouteInfoPickerViewHidden"), object: nil)
    }
    
    //MARK: - Update Notifications
    
    func setupRouteMapUpdateNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(updateMap(notification:)), name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAllAnnotations), name: NSNotification.Name("ReloadAnnotations"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showPickerView), name: NSNotification.Name("ShowRouteInfoPickerView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hidePickerView), name: NSNotification.Name("HideRouteInfoPickerView"), object: nil)
    }
    
    func removeRouteMapUpdateNotifications()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReloadAnnotations"), object: nil)
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance, willChangeRange: Bool = true)
    {
        mainMapView.setRegion(MKCoordinateRegion(center: mainMapView.region.center, latitudinalMeters: range, longitudinalMeters: range), animated: false)
        
        let offset = panelHalfSize-10-panelTipSize
        
        var point = mainMapView.convert(location.coordinate, toPointTo: self.view)
        point.y += offset/2
        let offsetCoordinate = mainMapView.convert(point, toCoordinateFrom: self.view)
        
        mainMapView.setRegion(MKCoordinateRegion(center: offsetCoordinate, latitudinalMeters: range, longitudinalMeters: range), animated: !willChangeRange)
    }
        
    @objc func updateMap(notification: Notification?)
    {
        switch MapState.routeInfoShowing
        {
        case .none:
            resetAnnotations()
            
            hidePredictionNavigationBar()
                        
            mainNavigationItem.title = "Map"
        case .direction:
            reloadAllAnnotations()
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            if let direction = MapState.getCurrentDirection(), let location = self.mainMapView?.userLocation.location
            {
                let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: direction.stops!.array as! [Stop], locationToTest: location)
                MapState.selectedStopTag = sortedStops[0].tag!
                updateSelectedStopAnnotation(stopTag: sortedStops[0].tag!)
                
                bringSelectedStopHeaderToFront()
            }
            
            showPickerView()
            
            hidePredictionNavigationBar()
                        
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.title
        case .stop:
            let changingRouteInfoShowing = notification?.userInfo?["ChangingRouteInfoShowing"] as? Bool ?? true
            
            if let stop = MapState.getCurrentStop()
            {
                let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                
                centerMapOnLocation(location: stopLocation, range: 1000, willChangeRange: changingRouteInfoShowing)
                
                setAnnotationType(coordinate: selectedAnnotationLocation, annotationType: .red)
                setAnnotationType(coordinate: stopLocation.coordinate.convertToString(), annotationType: .orange)
                
                reloadCurrentStopHeader(stopLocation: stopLocation)
                bringSelectedStopHeaderToFront()
                
                selectedAnnotationLocation = stopLocation.coordinate.convertToString()
            }
            
            showPredictionNavigationBar()
            
            refreshPredictionNavigationBar()
            
            if changingRouteInfoShowing
            {
                reloadPolyline()
            }
            
            showPickerView()
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.title
        case .otherDirections:
            reloadAllAnnotations()
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            hidePredictionNavigationBar()
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.title
        case .vehicles:
            reloadPredictionTimesLabel()
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.title
            
            let darkBusIcon = UIImage(named: "BusAnnotationDark")
            for busAnnotation in busAnnotations
            {
                if busAnnotation.value.annotationView?.image == darkBusIcon
                {
                    busAnnotation.value.annotationView?.image = UIImage(named: "BusAnnotation")
                }
                
                if busAnnotation.value.annotation.isMapKitSelected
                {
                    mainMapView.deselectAnnotation(busAnnotations[MapState.selectedVehicleID!]?.annotation, animated: false)
                }
            }
            
            busAnnotations[MapState.selectedVehicleID ?? ""]?.annotationView?.image = UIImage(named: "BusAnnotationDark")
        }
    }
    
    //MARK: - Annotations
    
    @objc func reloadAllAnnotations()
    {
        resetAnnotations()
        
        if let direction = MapState.getCurrentDirection()
        {
            for stop in direction.stops!.array
            {
                let stop = stop as! Stop
                addAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude), stopTag: stop.tag!)
            }
            
            reloadPolyline()
            
            NotificationCenter.default.addObserver(self, selector: #selector(fetchVehicleLocations), name: NSNotification.Name("FetchVehicleLocations"), object: nil)
            fetchPredictionTimes()
        }
    }
    
    func addAnnotation(coordinate: CLLocationCoordinate2D, stopTag: String, annotationType: AnnotationType = .red)
    {
        let annotation = StopAnnotation(coordinate: coordinate, stopTag: stopTag, annotationType: annotationType)
        
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
    }
    
    func reloadPolyline()
    {
        if directionPolyline != nil
        {
            mainMapView.removeOverlay(directionPolyline!)
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
            
            directionPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mainMapView.addOverlay(directionPolyline!)
        }
    }
    
    func reloadCurrentStopHeader(stopLocation: CLLocation)
    {
        if selectedStopHeading != nil
        {
            self.mainMapView.removeAnnotation(selectedStopHeading!)
        }
        selectedStopHeading = SelectedStopHeadingAnnotation(coordinate: stopLocation.coordinate, heading: calculateCurrentStopHeading())
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
        }
        
        return 0
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor(red: 0.972, green: 0.611, blue: 0.266, alpha: 1)
        if let route = MapState.getCurrentDirection()?.route
        {
            polylineRenderer.strokeColor = UIColor(hexString: route.color!)
        }
        polylineRenderer.lineWidth = 5
        return polylineRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let stopAnnotation = annotation as? StopAnnotation
        {
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "StopAnnotation")
            
            switch stopAnnotation.type
            {
            case .red:
                annotationView.image = UIImage(named: "SmallDot")
            case .orange:
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
        else if let stopAnnotation = view.annotation as? StopAnnotation
        {
            if MapState.routeInfoShowing == .stop
            {
                if MapState.selectedStopTag != stopAnnotation.stopTag
                {
                    MapState.selectedStopTag = stopAnnotation.stopTag
                    NotificationCenter.default.post(name: NSNotification.Name("SelectCurrentStop"), object: self)
                }
            }
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
            setAnnotationType(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude).convertToString(), annotationType: .orange)
            
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
    
    //MARK: - Segue
    
    @IBAction func routesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showRoutesTableView", sender: self)
    }
    
    @IBAction func favoritesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showFavoritesTableView", sender: self)
    }
    
    @IBAction func nearbyButtonPressed(_ sender: Any) {
        locationToUse = self.mainMapView.userLocation.location
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
            locationToUse = CLLocation(latitude: latitude, longitude: longitude)
            self.performSegue(withIdentifier: "showNearbyStopTableView", sender: self)
        }
    }
    
    var newStopNotification: StopNotification?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.predictionRefreshTimer?.invalidate()
        
        if segue.identifier == "showRecentStopTableView"
        {
            let stopsTableView = segue.destination as! StopsTableViewController
            stopsTableView.stopFetchType = .recent
        }
        else if segue.identifier == "showNearbyStopTableView"
        {
            let stopsTableView = segue.destination as! StopsTableViewController
            stopsTableView.stopFetchType = .nearby
            stopsTableView.locationToFetchFrom = locationToUse
        }
        else if segue.identifier == "openNewNotificationEditor"
        {
            let notificationEditorView = segue.destination as! NotificationEditorViewController
            notificationEditorView.stopNotification = self.newStopNotification
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
        reloadAllAnnotations()
        NotificationCenter.default.post(name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromFavoritesView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromSettingsView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromOtherDirectionsView(_ segue: UIStoryboardSegue)
    {
        MapState.routeInfoObject = MapState.getCurrentDirection()
        showPickerView()
    }
    
    @IBAction func unwindFromStopsTableViewWithSelectedStop(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations()
        NotificationCenter.default.post(name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromFavoritesViewWithSelectedRoute(_ segue: UIStoryboardSegue)
    {
        showPickerView()
        reloadAllAnnotations()
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
            //self.predictionTimesProgressView.isHidden = false
            
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
    
    func setupPredictionRefreshTimer()
    {
        if let refreshTime = UserDefaults.standard.object(forKey: "predictionRefreshTime") as? TimeInterval, refreshTime > 0.0
        {
            self.predictionRefreshTimer?.invalidate()
            self.predictionRefreshTimer = Timer.scheduledTimer(timeInterval: refreshTime, target: self, selector: #selector(self.refreshPredictionNavigationBar), userInfo: nil, repeats: true)
        }
    }
    
    func hidePredictionNavigationBar()
    {
        OperationQueue.main.addOperation {
            self.predictionBarTopConstraint.constant = -1*(self.predictionTimesNavigationBar.frame.size.height)
            
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutSubviews()
            }) { (bool) in
                self.predictionTimesNavigationBar.isHidden = true
                self.vehicleSelectionButton.isEnabled = false
                self.vehicleSelectionButton.isHidden = true
                self.predictionTimesProgressView.isHidden = true
            }
                        
            self.predictionRefreshTimer?.invalidate()
            self.activityIndicator.stopAnimating()
        }
    }
    
    @objc @IBAction func refreshPredictionNavigationBar()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchVehicleLocations), name: NSNotification.Name("FetchVehicleLocations"), object: nil)
        
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(0, animated: false)
            self.predictionTimesProgressView.isHidden = false
            self.predictionTimesProgressViewConstraint.constant = 0
            
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutSubviews()
            })
        }
        
        fetchPredictionTimes()
    }
    
    func fetchPredictionTimes()
    {
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(0.33, animated: true)
        }
        
        let predictionTimesReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTimes(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: MapState.getCurrentStop(), direction: MapState.getCurrentDirection())
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = false
            self.refreshButton.tintColor = .clear
            
            if self.predictionNavigationBarShowing
            {
                self.activityIndicator.startAnimating()
            }
        }
    }
    
    @objc func fetchVehicleLocations()
    {
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(0.66, animated: true)
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FetchVehicleLocations"), object: nil)
        
        let vehicleLocationsReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveVehicleLocations(_:)), name: NSNotification.Name("FoundVehicleLocations:" + vehicleLocationsReturnUUID), object: nil)
        
        RouteDataManager.fetchVehicleLocations(returnUUID: vehicleLocationsReturnUUID, vehicleIDs: vehicleIDs, direction: MapState.getCurrentDirection())
    }
    
    @objc func receivePredictionTimes(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = true
            self.refreshButton.tintColor = UIColor(red: 0, green: 0.4, blue: 1.0, alpha: 1)
            self.activityIndicator.stopAnimating()
        }
        
        if let predictions = notification.userInfo!["predictions"] as? Array<String>
        {
            self.predictions = predictions
            
            if let vehicleIDs = notification.userInfo!["vehicleIDs"] as? Array<String>
            {
                self.vehicleIDs = vehicleIDs
                
                NotificationCenter.default.post(name: NSNotification.Name("FetchVehicleLocations"), object: nil)
            }
            
            reloadPredictionTimesLabel()
        }
        else if let error = notification.userInfo!["error"] as? String
        {
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = error
            }
        }
    }
    
    func reloadPredictionTimesLabel()
    {
        let predictionsFormatCallback = RouteDataManager.formatPredictions(predictions: self.predictions, vehicleIDs: self.vehicleIDs)
        let predictionsString = predictionsFormatCallback.predictionsString
        let selectedVehicleRange = predictionsFormatCallback.selectedVehicleRange
        
        OperationQueue.main.addOperation {
            if selectedVehicleRange != nil
            {
                let predictionsAttributedString = NSMutableAttributedString(string: predictionsString, attributes: [:])
                predictionsAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(red: 0, green: 0.5, blue: 1, alpha: 1), range: selectedVehicleRange!)
                self.predictionTimesLabel.attributedText = predictionsAttributedString
            }
            else
            {
                self.predictionTimesLabel.attributedText = nil
                self.predictionTimesLabel.text = predictionsString
            }
        }
    }
    
    @objc func receiveVehicleLocations(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        OperationQueue.main.addOperation {
            self.predictionTimesProgressView.setProgress(1, animated: true)
            self.predictionTimesProgressViewConstraint.constant = -self.predictionTimesProgressView.frame.size.height
            
            UIView.animate(withDuration: 0.75, animations: {
                self.view.layoutSubviews()
            }) { (bool) in
                self.predictionTimesProgressView.isHidden = true
            }
            
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
                    //self.mainMapView.removeAnnotation(headingAnnotation)
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
    
    //MARK: - Tracking
    
    @IBAction func toggleVehiclesButtonPressed(_ sender: Any) {
        if MapState.routeInfoShowing != .vehicles && vehicleIDs.count == predictions.count
        {
            var predictionVehicleArray = Array<(vehicleID: String, prediction: String)>()
            
            var vehicleOn = 0
            while vehicleOn < vehicleIDs.count
            {
                predictionVehicleArray.append((vehicleID: vehicleIDs[vehicleOn], prediction: predictions[vehicleOn]))
                vehicleOn += 1
            }
            
            MapState.routeInfoObject = predictionVehicleArray
            MapState.routeInfoShowing = .vehicles
            
            showPickerView()
        }
        else if MapState.routeInfoShowing == .vehicles
        {
            MapState.routeInfoObject = MapState.getCurrentDirection()
            MapState.routeInfoShowing = .stop
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
}

class StopAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var type: AnnotationType = .red
    var stopTag: String?
    
    init(coordinate: CLLocationCoordinate2D, stopTag: String, annotationType: AnnotationType = .red)
    {
        self.coordinate = coordinate
        self.type = annotationType
        self.stopTag = stopTag
    }
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, annotationType: AnnotationType = .red)
    {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = annotationType
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
            case .half: return panelHalfSize
            case .tip: return panelTipSize
            default: return nil // Or `case .hidden: return nil`
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
