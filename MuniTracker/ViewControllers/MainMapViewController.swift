//
//  MainMapViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import MapKit

let appDelegate = UIApplication.shared.delegate as! AppDelegate

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

class MainMapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mainMapView: MKMapView!
    @IBOutlet weak var predictionTimesNavigationBar: UINavigationBar!
    @IBOutlet weak var predictionTimesLabel: UILabel!
    @IBOutlet weak var addFavoriteButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var mainToolbar: UIToolbar!
    @IBOutlet weak var showHidePickerButton: UIBarButtonItem!
    @IBOutlet weak var vehicleSelectionButton: UIButton!
    @IBOutlet weak var pickerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var predictionBarTopConstraint: NSLayoutConstraint!
    
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
    
    //MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        mainMapView.showsUserLocation = true
        mainMapView.isRotateEnabled = false
        centerMapOnLocation(location: initialLocation, range: 15000)
        
        setupRouteMapUpdateNotifications()
        
        setupHidePickerButton()
        
        if appDelegate.firstLaunch
        {
            downloadAllData = true
        }
        
        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = offWhite
            self.predictionTimesNavigationBar.barTintColor = nil
            self.predictionTimesLabel.textColor = black
            self.mainNavigationBar.barTintColor = offWhite
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
            self.mainToolbar.barTintColor = offWhite
            self.activityIndicator.activityIndicatorViewStyle = .gray
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
        case .dark:
            self.view.backgroundColor = black
            self.predictionTimesNavigationBar.barTintColor = black
            self.predictionTimesLabel.textColor = white
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
            self.mainToolbar.barTintColor = black
            self.activityIndicator.activityIndicatorViewStyle = .white
            self.vehicleSelectionButton.setImage(UIImage(named: "BusIcon" + darkImageAppend()), for: UIControl.State.normal)
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
    
    @objc func showPickerView()
    {
        MapState.showingPickerView = true
        self.pickerViewBottomConstraint.constant = 0
        self.view.viewWithTag(618)?.isHidden = false
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutSubviews()
        }) { (bool) in
            self.setupHidePickerButton()
        }
    }
    
    @objc func hidePickerView()
    {
        NotificationCenter.default.post(name: NSNotification.Name("CollapseFilters"), object: self)
        
        MapState.showingPickerView = false
        self.pickerViewBottomConstraint.constant = -1*(self.view.viewWithTag(618)?.frame.size.height ?? 0)
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutSubviews()
        }) { (bool) in
            self.view.viewWithTag(618)?.isHidden = true
            self.setupShowPickerButton()
        }
    }
    
    func setupHidePickerButton()
    {
        showHidePickerButton.title = "Hide"
        showHidePickerButton.target = self
        showHidePickerButton.action = #selector(hidePickerView)
    }
    
    func setupShowPickerButton()
    {
        showHidePickerButton.title = "Show"
        showHidePickerButton.target = self
        showHidePickerButton.action = #selector(showPickerView)
    }
    
    //MARK: - Update Notifications
    
    func setupRouteMapUpdateNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(updateMap(notification:)), name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAllAnnotations), name: NSNotification.Name("ReloadAnnotations"), object: nil)
    }
    
    func removeRouteMapUpdateNotifications()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateRouteMap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReloadAnnotations"), object: nil)
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance, willChangeRange: Bool = true)
    {
        mainMapView.setRegion(MKCoordinateRegion(center: mainMapView.region.center, latitudinalMeters: range, longitudinalMeters: range), animated: false)
        
        let offset = self.view.viewWithTag(618)?.frame.height ?? 0
        
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
            
            showHidePickerButton.isEnabled = false
            
            mainNavigationItem.title = "Map"
        case .direction:
            reloadAllAnnotations()
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            if let direction = MapState.getCurrentDirection(), let location = self.mainMapView?.userLocation.location
            {
                let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: direction.stops!.array as! [Stop], locationToTest: location)
                MapState.selectedStopTag = sortedStops[0].stopTag!
                updateSelectedStopAnnotation(stopTag: sortedStops[0].stopTag!)
                
                bringSelectedStopHeaderToFront()
            }
            
            hidePredictionNavigationBar()
            
            showHidePickerButton.isEnabled = true
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.routeTitle
        case .stop:
            let changingRouteInfoShowing = notification?.userInfo?["ChangingRouteInfoShowing"] as? Bool ?? true
            
            if let stop = MapState.getCurrentStop()
            {
                let stopLocation = CLLocation(latitude: stop.stopLatitude, longitude: stop.stopLongitude)
                
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
            
            setFavoriteButtonImage(inverse: false)
            
            showHidePickerButton.isEnabled = true
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.routeTitle
        case .otherDirections:
            reloadAllAnnotations()
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            hidePredictionNavigationBar()
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.routeTitle
        case .vehicles:
            reloadPredictionTimesLabel()
            
            mainNavigationItem.title = MapState.getCurrentDirection()?.route?.routeTitle
            
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
                addAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude), stopTag: stop.stopTag!)
            }
            
            reloadPolyline()
            
            fetchVehicleLocations()
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
                    coordinates.append(CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude))
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
                
                let nextStopCoordinate = CLLocationCoordinate2D(latitude: nextStopObject.stopLatitude, longitude: nextStopObject.stopLongitude)
                let currentStopCoordinate = CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude)
                
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
            polylineRenderer.strokeColor = UIColor(hexString: route.routeColor!)
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
                UIColor(hexString: route.routeColor!).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                
                if brightness > 0.6
                {
                    annotationView.image = annotationView.image?.colorized(color: UIColor(hexString: route.routeColor!))
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
            let headingImage = UIImage(named: "HeadingIndicator")!
            let busImageSize = headingAnnotation.busAnnotationViewImageSize ?? UIImage(named: "BusAnnotation")!.size
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "HeadingAnnotation")
            annotationView.centerOffset = calculateOffsetForAnnotationView(busImageSize: busImageSize, headingImageSize: headingImage.size, headingValue: headingAnnotation.headingValue)
            annotationView.image = headingImage
            
            annotationView.transform = calculateHeadingDegreeShift(headingValue: headingAnnotation.headingValue)
            
            annotationView.isEnabled = false
            
            self.busAnnotations[headingAnnotation.id]!.headingAnnotationView = annotationView
            
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
                UIColor(hexString: route.routeColor!).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                
                if brightness > 0.6
                {
                    annotationView.image = annotationView.image?.colorized(color: UIColor(hexString: route.routeColor!))
                    
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
    
    func updateSelectedStopAnnotation(stopTag: String)
    {
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", stopTag), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop
        {
            setAnnotationType(coordinate: CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude).convertToString(), annotationType: .orange)
            
            reloadCurrentStopHeader(stopLocation: CLLocation(latitude: stop.stopLatitude, longitude: stop.stopLongitude))
            
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
        MapState.showingPickerView = true
        setupHidePickerButton()
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
    }
    
    @IBAction func unwindFromStopsTableViewWithSelectedStop(_ segue: UIStoryboardSegue)
    {
        MapState.showingPickerView = true
        setupHidePickerButton()
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
    
    //MARK: - Bus Predications
    
    func showPredictionNavigationBar()
    {
        OperationQueue.main.addOperation {
            self.predictionBarTopConstraint.constant = 0
            
            self.predictionTimesNavigationBar.isHidden = false
            self.vehicleSelectionButton.isEnabled = true
            self.vehicleSelectionButton.isHidden = false
            
            UIView.animate(withDuration: 0.5) {
                self.view.layoutSubviews()
            }
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
            }
        }
    }
    
    @IBAction func refreshPredictionNavigationBar()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchVehicleLocations), name: NSNotification.Name("FetchVehicleLocations"), object: nil)
        
        fetchPredictionTimes()
    }
    
    func fetchPredictionTimes()
    {
        let predictionTimesReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTimes(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: MapState.getCurrentStop(), direction: MapState.getCurrentDirection())
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = false
            self.refreshButton.tintColor = .clear
            self.activityIndicator.startAnimating()
        }
    }
    
    @objc func fetchVehicleLocations()
    {
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
        let predictionsFormatCallback = MapState.formatPredictions(predictions: self.predictions, vehicleIDs: self.vehicleIDs)
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
                        let headingImage = UIImage(named: "HeadingIndicator")!
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
    
    //MARK: - Add Favorite
    
    @IBAction func addFavoriteButtonPressed(_ sender: Any) {
        setFavoriteButtonImage(inverse: true)
        
        NotificationCenter.default.post(name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
    }
    
    func setFavoriteButtonImage(inverse: Bool)
    {
        if MapState.selectedStopTag != nil
        {
            if let stop = MapState.getCurrentStop(), let direction = MapState.getCurrentDirection()
            {
                var stopIsFavorite = RouteDataManager.favoriteStopExists(stopTag: stop.stopTag!, directionTag: direction.directionTag!)
                if inverse
                {
                    stopIsFavorite = !stopIsFavorite
                }
                
                if stopIsFavorite
                {
                    addFavoriteButton.image = UIImage(named:  "FavoriteAddFillIcon")
                }
                else
                {
                    addFavoriteButton.image = UIImage(named: "FavoriteAddIcon")
                }
            }
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