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

enum StopDisplayType: Int
{
    case favorite
    case nearby
    case recent
}

class StopsWatchInterfaceController: MuniTrackerWatchInterfaceController, CLLocationManagerDelegate
{
    @IBOutlet weak var stopsTable: WKInterfaceTable!
    
    var currentUserLocation: CLLocation?
    var locationManager = CLLocationManager()
    
    var stopDisplayType: StopDisplayType = .favorite
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        stopDisplayType = StopDisplayType(rawValue: (UserDefaults.standard.object(forKey: "StopDisplayType") as? Int) ?? 0) ?? .favorite
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
    }
    
    var justLoaded = true
    
    override func willActivate() {
        if justLoaded
        {
            justLoaded = false
            NotificationCenter.default.addObserver(self, selector: #selector(loadStops), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            DispatchQueue.global(qos: .background).async
            {
                RouteDataManager.updateAllData()
            }
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.first else { return }
        let oldUserLocation = currentUserLocation
        currentUserLocation = locations.first
        
        if oldUserLocation == nil || newLocation.distance(from: oldUserLocation!) >= 100
        {
            loadStops()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    @IBAction func favoriteSelected() {
        self.stopDisplayType = .favorite
        loadStops()
    }
    
    @IBAction func nearbySelected() {
        self.stopDisplayType = .nearby
        loadStops()
    }
    
    @IBAction func recentSelected() {
        self.stopDisplayType = .recent
        loadStops()
    }
    
    @objc func loadStops()
    {
        UserDefaults.standard.set(stopDisplayType.rawValue, forKey: "StopDisplayType")
        directionStopObjects = []
        
        switch stopDisplayType
        {
        case .favorite:
            self.setTitle("Favorites")
            loadClosestFavoriteStops()
            if directionStopObjects?.count == 0 { setupMOCSaveNotification() }
        case .nearby:
            self.setTitle("Nearby")
            loadNearbyStops()
        case .recent:
            self.setTitle("Recent")
            loadRecentStops()
            if directionStopObjects?.count == 0 { setupMOCSaveNotification() }
        }
    }
    
    func setupMOCSaveNotification()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(mocDidSave), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
    }
    
    @objc func mocDidSave()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        loadStops()
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
            
            self.directionStopObjects = favoriteStops.map({ (favoriteStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: favoriteStop.stopTag!, directionTag: favoriteStop.directionTag!)
            })
            
            self.updateTable(directionStopTable: self.stopsTable)
        }
    }
    
    func loadNearbyStops()
    {
        if let currentLocation = locationManager.location
        {
            let latitude = currentLocation.coordinate.latitude
            let longitude = currentLocation.coordinate.longitude
            let mileDegree = 0.01449
            
            if let nearbyStops = RouteDataManager.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", latitude - mileDegree, latitude + mileDegree, longitude - mileDegree, longitude + mileDegree), moc: CoreDataStack.persistentContainer.viewContext) as? [Stop]
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
    
    func loadRecentStops()
    {
        if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: numStopsToDisplay) as? [RecentStop]
        {
            self.directionStopObjects = recentStops.map({ (recentStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: recentStop.stopTag!, directionTag: recentStop.directionTag!)
            })
            
            self.updateTable(directionStopTable: self.stopsTable)
        }
    }
}
