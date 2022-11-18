//
//  TodayViewController.swift
//  BussrNearbyExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation

class NearbyExtensionViewController: BussrExtensionViewController, CLLocationManagerDelegate {
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
            let mileDegree = 0.01449
            
            if let nearbyStops = CoreDataStack.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", latitude - mileDegree, latitude + mileDegree, longitude - mileDegree, longitude + mileDegree), moc: CoreDataStack.persistentContainer.viewContext) as? [Stop]
            {
                let sortedNearbyStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: nearbyStops, locationToTest: currentLocation)
                
                var nearbyDirectionStops = Array<(stop: Stop, direction: Direction)>()
                for stop in sortedNearbyStops
                {
                    guard let directions = stop.direction?.allObjects as? [Direction] else { continue }
                    for direction in directions
                    {
                        nearbyDirectionStops.append((stop: stop, direction: direction))
                    }
                }
                
                var nearbyDirections = Array<String>()
                var directionStopOn = 0
                for directionStop in nearbyDirectionStops
                {
                    guard let directionTag = directionStop.direction.tag else { continue }
                    if !nearbyDirections.contains(directionTag)
                    {
                        nearbyDirections.append(directionTag)
                        directionStopOn += 1
                    }
                    else
                    {
                        nearbyDirectionStops.remove(at: directionStopOn)
                    }
                }
                
                var defaultCut = 20
                if nearbyDirectionStops.count < defaultCut
                {
                    defaultCut = nearbyDirectionStops.count
                }
                
                self.stopDirectionObjects = nearbyDirectionStops.map({ (directionStop) -> (stopTag: String, directionTag: String) in
                    return (stopTag: directionStop.stop.tag ?? "", directionTag: directionStop.direction.tag ?? "")
                })
                
                self.tableView.reloadData()
            }
        }
    }
}
