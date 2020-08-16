//
//  FavoritesWatchInterfaceController.swift
//  BussrWatchApp Extension
//
//  Created by jackson on 8/15/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import WatchKit
import CoreLocation

class FavoritesWatchInterfaceController: BussrWatchInterfaceController
{
    @IBOutlet weak var stopsTable: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        super.willActivate()
        
        locationManager.startUpdatingLocation()
    }
    
    @objc override func loadStops()
    {
        super.loadStops()
        loadClosestFavoriteStops()
    }
    
    func loadClosestFavoriteStops()
    {
        if let userLocation = self.currentUserLocation, var favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext) as? [FavoriteStop]
        {
            favoriteStops = favoriteStops.filter({ (favoriteStop) -> Bool in
                if favoriteStop.directionTag == nil || favoriteStop.stopTag == nil { return false }
                return RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!) != nil && RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!) != nil
            })
            
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
            
            self.updateTable(directionStopTable: self.stopsTable)
        }
    }
}
