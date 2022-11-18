//
//  NearbyWatchInterfaceController.swift
//  BussrWatchApp Extension
//
//  Created by jackson on 8/15/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import WatchKit
import CoreLocation

class NearbyWatchInterfaceController: BussrWatchInterfaceController
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
        loadNearbyStops()
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
                
                self.directionStopObjects = nearbyDirectionStops.map({ (directionStop) -> (stopTag: String, directionTag: String) in
                    return (stopTag: directionStop.stop.tag ?? "", directionTag: directionStop.direction.tag ?? "")
                })
                
                self.updateTable(directionStopTable: self.stopsTable)
            }
        }
    }
}
