//
//  ViewController.swift
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

extension CLLocation
{
    func convertToString() -> String
    {
        return String(self.coordinate.latitude) + "-" + String(self.coordinate.longitude)
    }
}

class MainMapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mainMapView: MKMapView!
    @IBOutlet weak var predictionTimesNavigationBar: UINavigationBar!
    @IBOutlet weak var predictionTimesLabel: UILabel!
    @IBOutlet weak var addFavoriteButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var showHidePickerButton: UIBarButtonItem!
    
    //37.773972
    //37.738802
    let initialLocation = CLLocation(latitude: 37.773972, longitude: -122.438765)
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    var selectedAnnotationLocation: String?
    var stopAnnotations = Dictionary<String,StopAnnotation>()
    var directionPolyline: MKPolyline?
    var busAnnotations = Dictionary<String,BusAnnotation>()
    
    var downloadAllData = false
    
    let showPickerViewButton = UIBarButtonItem(title: "Show", style: UIBarButtonItem.Style.done, target: self, action: #selector(showPickerView))
    let hidePickerViewButton = UIBarButtonItem(title: "Hide", style: UIBarButtonItem.Style.done, target: self, action: #selector(hidePickerView))

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        
        centerMapOnLocation(location: initialLocation, range: 15000)
        
        setupRouteMapUpdateNotifications()
        
        setupHidePickerButton()
        
        if appDelegate.firstLaunch
        {
            downloadAllData = true
        }
    }
    
    @objc func showPickerView()
    {
        MapState.showingPickerView = true
        
        self.view.viewWithTag(618)?.isHidden = false
        
        setupHidePickerButton()
    }
    
    @objc func hidePickerView()
    {
        MapState.showingPickerView = false
        
        self.view.viewWithTag(618)?.isHidden = true
        
        setupShowPickerButton()
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
    
    func setupRouteMapUpdateNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(focusMapFromRouteObject(notification:)), name: NSNotification.Name("UpdateRouteMap"), object: nil)
    }
    
    func removeRouteMapUpdateNotifications()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateRouteMap"), object: nil)
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
        })
    }
    
    @IBAction func routesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showRoutesTableView", sender: self)
    }
    
    @objc func focusMapFromRouteObject(notification: Notification)
    {
        switch MapState.routeInfoShowing
        {
        case .none:
            resetAnnotations()
            
            hidePredictionNavigationBar()
            
            showHidePickerButton.isEnabled = false
        case .direction:
            resetAnnotations()
            
            if let direction = RouteDataManager.getCurrentDirection()
            {
                for stop in direction.stops!.array
                {
                    let stop = stop as! Stop
                    addAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude))
                }
                
                reloadPolyline()
                
                addBusAnnotations()
            }
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            hidePredictionNavigationBar()
            
            showHidePickerButton.isEnabled = true
        case .stop:
            let changingRouteInfoShowing = notification.userInfo!["ChangingRouteInfoShowing"] as! Bool
            
            if let stop = RouteDataManager.getCurrentStop()
            {
                let stopLocation = CLLocation(latitude: stop.stopLatitude, longitude: stop.stopLongitude)
                
                centerMapOnLocation(location: stopLocation, range: 1000, willChangeRange: changingRouteInfoShowing)
                
                setAnnotationType(coordinate: selectedAnnotationLocation, annotationType: .red)
                setAnnotationType(coordinate: stopLocation.convertToString(), annotationType: .orange)
                
                selectedAnnotationLocation = stopLocation.convertToString()
            }
            
            showPredictionNavigationBar()
            
            refreshPredictionNavigationBar()
            
            if changingRouteInfoShowing
            {
                reloadPolyline()
            }
            
            setFavoriteButtonImage(inverse: false)
            
            showHidePickerButton.isEnabled = true
        }
    }
    
    func addAnnotation(coordinate: CLLocationCoordinate2D, annotationType: AnnotationType = .red)
    {
        let annotation = StopAnnotation(coordinate: coordinate, annotationType: annotationType)
        
        mainMapView.addAnnotation(annotation)
        stopAnnotations[CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).convertToString()] = annotation
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
        
        if let direction = RouteDataManager.getCurrentDirection()
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
    
    func addBusAnnotations()
    {
        for annotation in busAnnotations
        {
            mainMapView.addAnnotation(annotation.value)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor(red: 0.972, green: 0.611, blue: 0.266, alpha: 1)
        polylineRenderer.lineWidth = 5
        return polylineRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        //let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView")
        let annotationView = MKAnnotationView()
        
        if let stopAnnotation = annotation as? StopAnnotation
        {
            switch stopAnnotation.type
            {
            case .red:
                annotationView.image = UIImage(named: "RedDot")
            case .orange:
                annotationView.image = UIImage(named: "OrangeDot")
            }
            
        }
        else if annotation is BusAnnotation
        {
            annotationView.image = UIImage(named: "BusAnnotation")
        }
        
        return annotationView
    }
    
    @IBAction func unwindFromRouteTableViewWithSelectedRoute(_ segue: UIStoryboardSegue)
    {
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromRouteTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromSettingsView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    func showPredictionNavigationBar()
    {
        UIView.animate(withDuration: 1) {
            self.predictionTimesNavigationBar.isHidden = false
            self.addFavoriteButton.isEnabled = true
            self.addFavoriteButton.isHidden = false
        }
    }
    
    func hidePredictionNavigationBar()
    {
        UIView.animate(withDuration: 1) {
            self.predictionTimesNavigationBar.isHidden = true
            self.addFavoriteButton.isEnabled = false
            self.addFavoriteButton.isHidden = true
        }
    }
    
    @IBAction func refreshPredictionNavigationBar()
    {
        let predictionTimesReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTimes(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID)
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = false
            self.refreshButton.tintColor = .clear
            self.activityIndicator.startAnimating()
        }
        
        let vehicleLocationsReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveVehicleLocations(_:)), name: NSNotification.Name("FoundVehicleLocations:" + vehicleLocationsReturnUUID), object: nil)
        RouteDataManager.fetchVehicleLocations(returnUUID: vehicleLocationsReturnUUID)
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
            var predictionsString = ""
            var predictionOn = 0
            
            for prediction in predictions
            {
                if predictionOn != 0
                {
                    predictionsString += ", "
                }
                
                if prediction == "0"
                {
                    predictionsString += "Now"
                }
                else
                {
                    predictionsString += prediction
                }
                
                predictionOn += 1
            }
            
            if predictions.count > 0
            {
                predictionsString += " mins"
            }
            else
            {
                predictionsString = "No Predictions"
            }
            
            
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = predictionsString
            }
        }
        else if let error = notification.userInfo!["error"] as? String
        {
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = error
            }
        }
    }
    
    @objc func receiveVehicleLocations(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        let vehicleLocations = notification.userInfo!["vehicleLocations"] as! Array<(id: String, location: CLLocation, heading: Int)>
        for vehicleLocation in vehicleLocations
        {
            if let annotation = busAnnotations[vehicleLocation.id]
            {
                mainMapView.removeAnnotation(annotation)
            }
            busAnnotations[vehicleLocation.id] = BusAnnotation(coordinate: vehicleLocation.location.coordinate, heading: vehicleLocation.heading, id: vehicleLocation.id)
        }
        
        addBusAnnotations()
    }
    
    @IBAction func addFavoriteButtonPressed(_ sender: Any) {
        setFavoriteButtonImage(inverse: true)
        
        NotificationCenter.default.post(name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
    }
    
    func setFavoriteButtonImage(inverse: Bool)
    {
        if MapState.selectedStopTag != nil
        {
            if let stop = RouteDataManager.getCurrentStop()
            {
                var stopIsFavorite = stop.favorite
                if inverse
                {
                    stopIsFavorite = !stopIsFavorite
                }
                
                if stopIsFavorite
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddFillIcon"), for: UIControl.State.normal)
                }
                else
                {
                    addFavoriteButton.setImage(UIImage(named: "FavoriteAddIcon"), for: UIControl.State.normal)
                }
            }
        }
    }
}

class StopAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var type: AnnotationType = .red
    
    init(coordinate: CLLocationCoordinate2D, annotationType: AnnotationType = .red)
    {
        self.coordinate = coordinate
        self.type = annotationType
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
    var coordinate: CLLocationCoordinate2D
    var heading: Int
    var id: String
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, heading: Int, id: String)
    {
        self.coordinate = coordinate
        self.heading = heading
        self.id = id
    }
}
