//
//  ViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import MapKit

class MainMapViewController: UIViewController {
    @IBOutlet weak var mainMapView: MKMapView!
    let initialLocation = CLLocation(latitude: 37.738802, longitude: -122.438765)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        centerMapOnLocation(location: initialLocation, range: 15000)        
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance)
    {
        mainMapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: range, longitudinalMeters: range), animated: false)
    }


}

