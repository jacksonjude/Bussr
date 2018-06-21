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

class MainMapViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mainMapView: MKMapView!
    let initialLocation = CLLocation(latitude: 37.738802, longitude: -122.438765)
    var progressAlertView: UIAlertController?
    var routeToDisplay: Route?
    {
        didSet
        {
            if routeToDisplay != nil
            {
                
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        
        centerMapOnLocation(location: initialLocation, range: 15000)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        progressAlertView = UIAlertController(title: "Updating", message: "Updating route data...", preferredStyle: .alert)
        progressAlertView!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        var progressView: UIProgressView?
        
        self.present(progressAlertView!, animated: true, completion: {
            let margin: CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
            progressView = UIProgressView(frame: rect)
            progressView!.tintColor = UIColor.blue
            self.progressAlertView!.view.addSubview(progressView!)
            
            appDelegate.saveContext()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.dismissAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            DispatchQueue.global(qos: .background).async
                {
                    RouteDataManager.updateAllData(progressView!)
            }
        })
        
        
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance)
    {
        mainMapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: range, longitudinalMeters: range), animated: false)
    }

    @objc func dismissAlertView()
    {
        progressAlertView?.dismiss(animated: true, completion: {
            
        })
    }
    
    func addAnnotation(coordinate: CLLocationCoordinate2D)
    {
        let annotation = StopAnnotation(coordinate: coordinate)
        
        mainMapView.addAnnotation(annotation)
    }
    
    func resetAnnotations()
    {
        mainMapView.removeAnnotations(mainMapView.annotations)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        //let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView")
        let annotationView = MKAnnotationView()
        annotationView.image = UIImage(named: "RedDot")
        
        return annotationView
    }
}

class StopAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D!)
    {
        self.coordinate = coordinate
    }
    
    init(coordinate: CLLocationCoordinate2D!, title: String?, subtitle: String?)
    {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}
