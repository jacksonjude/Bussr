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
            self.mainNavigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.refresh, target: self, action: #selector(clearRecentStops))
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
                let halfMileDegree = 0.007245
                
                if let nearbyStops = RouteDataManager.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", latitude - halfMileDegree, latitude + halfMileDegree, longitude - halfMileDegree, longitude + halfMileDegree), moc: CoreDataStack.persistentContainer.viewContext) as? [Stop]
                {
                    var defaultCut = 20
                    if nearbyStops.count < defaultCut
                    {
                        defaultCut = nearbyStops.count
                    }
                    let sortedNearbyStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: nearbyStops, locationToTest: currentLocation)[0...defaultCut-1]
                    for stop in sortedNearbyStops
                    {
                        for direction in stop.direction!.allObjects
                        {
                            stopDirectionObjects?.append((stop: stop, direction: direction as! Direction))
                        }
                    }
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
            if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: 20) as? [RecentStop]
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
    
    @objc func clearRecentStops()
    {
        if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [RecentStop]
        {
            for recentStop in recentStops
            {
                CoreDataStack.persistentContainer.viewContext.delete(recentStop)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableViewAfterRecentStopClear(_:)), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        
        CoreDataStack.saveContext()
    }
    
    @objc func reloadTableViewAfterRecentStopClear(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        stopsTableView.reloadData()
    }
}
