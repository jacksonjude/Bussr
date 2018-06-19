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

class MainMapViewController: UIViewController {
    @IBOutlet weak var mainMapView: MKMapView!
    let initialLocation = CLLocation(latitude: 37.738802, longitude: -122.438765)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        centerMapOnLocation(location: initialLocation, range: 15000)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let alertView = UIAlertController(title: "Updating", message: "Updating route data...", preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        var progressView: UIProgressView?
        
        self.present(alertView, animated: true, completion: {
            let margin: CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: alertView.view.frame.width - margin * 2.0, height: 2.0)
            progressView = UIProgressView(frame: rect)
            progressView!.tintColor = UIColor.blue
            alertView.view.addSubview(progressView!)
            
            appDelegate.saveContext()
            
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


}

