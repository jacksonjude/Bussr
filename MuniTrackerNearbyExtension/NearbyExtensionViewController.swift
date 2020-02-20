//
//  TodayViewController.swift
//  MuniTrackerNearbyExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation

class NearbyExtensionViewController: MuniTrackerExtensionViewController, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.startUpdatingLocation()
        }
        
        self.loadNearbyStops()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        locationManager.stopUpdatingLocation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.loadNearbyStops()
    }
    
    override func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
        super.widgetPerformUpdate(completionHandler: completionHandler)
        
        self.loadNearbyStops()
    }
    
    func loadNearbyStops()
    {
        if let currentLocation = locationManager.location
        {
            let latitude = currentLocation.coordinate.latitude
            let longitude = currentLocation.coordinate.longitude
            let halfMileDegree = 0.007245
            
            if let nearbyStops = RouteDataManager.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", latitude - halfMileDegree, latitude + halfMileDegree, longitude - halfMileDegree, longitude + halfMileDegree), moc: CoreDataStack.persistentContainer.viewContext) as? [Stop]
            {
                var defaultCut = 20
                if nearbyStops.count < defaultCut
                {
                    defaultCut = nearbyStops.count
                }
                let sortedNearbyStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: nearbyStops, locationToTest: currentLocation)[0...defaultCut-1]
                                
                stopDirectionObjects = []
                for stop in sortedNearbyStops
                {
                    for direction in stop.direction!.allObjects
                    {
                        stopDirectionObjects?.append((stopTag: stop.tag!, directionTag: (direction as! Direction).tag!))
                    }
                }
                
                self.tableView.reloadData()
            }
        }
    }
}
