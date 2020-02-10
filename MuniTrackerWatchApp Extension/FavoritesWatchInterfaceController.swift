//
//  FavoritesWatchViewController.swift
//  MuniTrackerWatchApp Extension
//
//  Created by jackson on 2/9/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import WatchKit
import CoreLocation

class FavoritesWatchInterfaceController: MuniTrackerWatchInterfaceController, CLLocationManagerDelegate
{
    @IBOutlet weak var favoritesTable: WKInterfaceTable!
    
    var currentUserLocation: CLLocation?
    var locationManager = CLLocationManager()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        self.directionStopTable = favoritesTable
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        loadClosestFavoriteStops()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentUserLocation = locations[0]
        
        loadClosestFavoriteStops()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    func loadClosestFavoriteStops()
    {
        if let userLocation = self.currentUserLocation, var favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [FavoriteStop]
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
            
            self.directionStopObjects = favoriteStops.map({ (favoriteStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: favoriteStop.stopTag!, directionTag: favoriteStop.directionTag!)
            })
            
            self.updateTable()
        }
    }
}
