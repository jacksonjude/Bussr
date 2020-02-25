//
//  TodayViewController.swift
//  MuniTrackerFavoritesExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation

class FavoritesExtensionViewController: MuniTrackerExtensionViewController, CLLocationManagerDelegate {
    var currentUserLocation: CLLocation?
    var locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
    
    override func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
        self.loadClosestFavoriteStops()
        
        super.widgetPerformUpdate(completionHandler: completionHandler)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentUserLocation = locations[0]
        
        loadClosestFavoriteStops()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    func loadClosestFavoriteStops()
    {
        if let userLocation = self.currentUserLocation, var favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext) as? [FavoriteStop]
        {
            favoriteStops.sort { (favoriteStop1, favoriteStop2) -> Bool in
                if let stop1 = RouteDataManager.fetchStop(stopTag: favoriteStop1.stopTag!), let stop2 = RouteDataManager.fetchStop(stopTag: favoriteStop2.stopTag!)
                {
                    let stop1Location = CLLocation(latitude: stop1.latitude, longitude: stop1.longitude)
                    let stop2Location = CLLocation(latitude: stop2.latitude, longitude: stop2.longitude)
                    return stop1Location.distance(from: userLocation) < stop2Location.distance(from: userLocation)
                }
                
                return false
            }
            
            self.stopDirectionObjects = favoriteStops.map({ (favoriteStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: favoriteStop.stopTag!, directionTag: favoriteStop.directionTag!)
            })
            
            self.tableView.reloadData()
        }
    }
}
