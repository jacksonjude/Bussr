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
    
    override func viewDidLoad() {
        reloadTableView()
        
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
            /*if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.coordinate
            {
                let latitude = currentLocation.latitude
                let longitude = currentLocation.longitude
                
                if let nearbyStops = RouteDataManager.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "stopLatitude >= %d AND stopLatitude <= %d AND stopLongitude >= %d AND stopLongitude <= %d", ), moc: CoreDataStack.persistentContainer.viewContext) as? [Stop]
                {
                    
                }
            }*/
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
            if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: 10) as? [RecentStop]
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
            if let location = appDelegate.mainMapViewController?.mainMapView.userLocation.location
            {
                let sortedStopObjects = RouteDataManager.sortStopsByDistanceFromLocation(stops: stopDirectionObjects.map {$0.stop}, locationToTest: location)
                stopDirectionObjects.sort(by: {
                    return (sortedStopObjects.firstIndex(of: $0.stop) ?? 0) < (sortedStopObjects.firstIndex(of: $1.stop) ?? 0)
                })
            }
            else
            {
                stopDirectionObjects.sort(by: {
                    return $0.stop.stopTitle!.compare($1.stop.stopTitle!) == .orderedAscending
                })
                
            }
        }
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        //let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = offWhite
            self.mainNavigationBar.barTintColor = offWhite
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
        case .dark:
            self.view.backgroundColor = black
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stopDirectionObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let stopCell = tableView.dequeueReusableCell(withIdentifier: "StopCell")!
        
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        var textColor = UIColor.black
        
        if let routeColor = stopDirectionObject.direction.route?.routeColor, let routeOppositeColor = stopDirectionObject.direction.route?.routeOppositeColor
        {
            stopCell.backgroundColor = UIColor(hexString: routeColor)
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        (stopCell.viewWithTag(600) as! UILabel).textColor = textColor
        (stopCell.viewWithTag(601) as! UILabel).textColor = textColor
        (stopCell.viewWithTag(602) as! UILabel).textColor = textColor
        (stopCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        (stopCell.viewWithTag(600) as! UILabel).text = stopDirectionObject.direction.route?.routeTag
        (stopCell.viewWithTag(601) as! UILabel).text = stopDirectionObject.direction.directionTitle
        (stopCell.viewWithTag(602) as! UILabel).text = stopDirectionObject.stop.stopTitle
        
        return stopCell
    }
    
    func fetchPrediction(stopObject: Stop, directionObject: Direction, index: Int)
    {
        let predictionTimesReturnUUID = UUID().uuidString + ";" + String(index)
        NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stopObject, direction: directionObject)
    }
    
    @objc func receivePrediction(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        if let predictions = notification.userInfo!["predictions"] as? [String]
        {
            OperationQueue.main.addOperation {
                let predictionsString = MapState.formatPredictions(predictions: predictions).predictionsString
                let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
                
                if let stopPredictionLabel = self.stopsTableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                {
                    self.loadedPredictions[indexRow] = true
                    stopPredictionLabel.text = predictionsString
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            let stopDirectionObject = stopDirectionObjects![indexPath.row]
            
            fetchPrediction(stopObject: stopDirectionObject.stop, directionObject: stopDirectionObject.direction, index: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        MapState.selectedDirectionTag = stopDirectionObject.direction.directionTag
        MapState.selectedStopTag = stopDirectionObject.stop.stopTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedStopUnwind", sender: self)
    }
}
