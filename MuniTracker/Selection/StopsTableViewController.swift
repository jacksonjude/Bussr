//
//  StopsTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 7/24/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import MapKit

enum StopFetchType
{
    case nearby
    case favorite
    case recent
}

class StopsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var stopsTableView: UITableView!
    
    var stopDirectionObjects: Array<(stop: Stop, direction: Direction)>?
    var loadedPredictions = Array<Bool>()
    var stopFetchType: StopFetchType = .nearby
    var locationToFetchFrom: CLLocation?
    
    override func viewDidLoad() {
        reloadTableView()
        
        if stopFetchType == .recent
        {
            self.mainNavigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.trash, target: self, action: #selector(clearRecentStops))
        }
        
        setupThemeElements()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
    }
    
    func reloadTableView()
    {
        fetchStopObjects()
        sortStopObjects()
        stopsTableView.reloadData()
    }
    
    func fetchStopObjects()
    {
        stopDirectionObjects = []
        switch stopFetchType
        {
        case .nearby:
            if let currentLocation = locationToFetchFrom ?? appDelegate.mainMapViewController?.mainMapView?.userLocation.location
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
                    
                    if UserDefaults.standard.object(forKey: "ShouldCollapseRoutes") as? Bool ?? true
                    {
                        var nearbyRoutes = Array<String>()
                        var directionStopOn = 0
                        for directionStop in nearbyDirectionStops
                        {
                            guard let routeTag = directionStop.direction.route?.tag else { continue }
                            if !nearbyRoutes.contains(routeTag)
                            {
                                nearbyRoutes.append(routeTag)
                                directionStopOn += 1
                            }
                            else
                            {
                                nearbyDirectionStops.remove(at: directionStopOn)
                            }
                        }
                    }
                    
                    var defaultCut = 20
                    if nearbyDirectionStops.count < defaultCut
                    {
                        defaultCut = nearbyDirectionStops.count
                    }
                    
                    self.stopDirectionObjects = Array<(stop: Stop, direction: Direction)>(nearbyDirectionStops[0...defaultCut-1])
                }
            }
            
            self.mainNavigationItem.title = "Nearby Stops"
            break
        case .favorite:
            if let favoriteStops = FavoriteState.favoriteObject as? Array<FavoriteStop>
            {
                for favoriteStop in favoriteStops
                {
                    if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
                    {
                        stopDirectionObjects?.append((stop: stop, direction: direction))
                    }
                }
            }
        case .recent:
            if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: 20) as? [RecentStop]
            {
                for recentStop in recentStops
                {
                    if let stop = RouteDataManager.fetchStop(stopTag: recentStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: recentStop.directionTag!)
                    {
                        stopDirectionObjects?.append((stop: stop, direction: direction))
                    }
                }
            }
            
            self.mainNavigationItem.title = "Recent Stops"
        }
        
        loadedPredictions = Array<Bool>()
        for _ in stopDirectionObjects!
        {
            loadedPredictions.append(false)
        }
    }
    
    func sortStopObjects()
    {
        if var stopDirectionObjects = self.stopDirectionObjects
        {
            if let location = appDelegate.mainMapViewController?.mainMapView?.userLocation.location
            {
                let sortedStopObjects = RouteDataManager.sortStopsByDistanceFromLocation(stops: stopDirectionObjects.map {$0.stop}, locationToTest: location)
                stopDirectionObjects.sort(by: {
                    return (sortedStopObjects.firstIndex(of: $0.stop) ?? 0) < (sortedStopObjects.firstIndex(of: $1.stop) ?? 0)
                })
            }
            else
            {
                stopDirectionObjects.sort(by: {
                    return $0.stop.title!.compare($1.stop.title!) == .orderedAscending
                })
                
            }
        }
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            break
        case .dark:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stopDirectionObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let stopCell = tableView.dequeueReusableCell(withIdentifier: "StopCell") as! DirectionStopCell
        
        let stopCellBackground = UIView()
        stopCellBackground.backgroundColor = UIColor(white: 0.7, alpha: 0.4)
        stopCell.selectedBackgroundView = stopCellBackground
        
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        stopCell.directionObject = stopDirectionObject.direction
        stopCell.stopObject = stopDirectionObject.stop
        
        stopCell.updateCellText()
        
        return stopCell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            (cell as! DirectionStopCell).refreshTimes()
            loadedPredictions[indexPath.row] = true
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        MapState.selectedDirectionTag = stopDirectionObject.direction.tag
        MapState.selectedStopTag = stopDirectionObject.stop.tag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedStopUnwind", sender: self)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return stopFetchType == .recent
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete && stopFetchType == .recent {
            let stopDirection = stopDirectionObjects![indexPath.row]
            if let recentStopFetch = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "directionTag == %@ AND stopTag == %@", stopDirection.direction.tag ?? "", stopDirection.stop.tag ?? ""), moc: CoreDataStack.persistentContainer.viewContext) as? [RecentStop], recentStopFetch.count > 0
            {
                CoreDataStack.persistentContainer.viewContext.delete(recentStopFetch[0])
                stopDirectionObjects?.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                CoreDataStack.saveContext()
            }
        }
    }
    
    @objc func clearRecentStops()
    {
        if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext) as? [RecentStop]
        {
            for recentStop in recentStops
            {
                CoreDataStack.persistentContainer.viewContext.delete(recentStop)
            }
        }
                
        let stopDirectionCount = stopDirectionObjects?.count ?? 0
        stopDirectionObjects = []
        stopsTableView.deleteRows(at: Array(0...stopDirectionCount-1).map({ (row) -> IndexPath in
            return IndexPath(row: row, section: 0)
        }), with: .automatic)
        
        CoreDataStack.saveContext()
    }
}
