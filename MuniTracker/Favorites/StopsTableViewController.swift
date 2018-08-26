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

class StopsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var stopsTableView: UITableView!
    
    var currentDirection: Direction?
    var favoriteStopObjects: Array<FavoriteStop>?
    var loadedPredictions = Array<Bool>()
    
    override func viewDidLoad() {
        reloadTableView()
        
        if let route = RouteDataManager.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", FavoriteState.selectedRouteTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Route
        {
            mainNavigationItem.title = route.routeTitle
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
        if let favoriteStops = FavoriteState.favoriteObject as? Array<FavoriteStop>
        {
            favoriteStopObjects = favoriteStops
            
            loadedPredictions = Array<Bool>()
            for _ in favoriteStops
            {
                loadedPredictions.append(false)
            }
        }
    }
    
    func sortStopObjects()
    {
        if var favoriteStopObjects = self.favoriteStopObjects
        {
            let favoriteStopTags = favoriteStopObjects.map {$0.stopTag!}
            
            if let location = appDelegate.mainMapViewController?.mainMapView.userLocation.location, let stopObjects = RouteDataManager.fetchLocalObjects(type: "Stop", predicate: NSPredicate(format: "stopTag IN %@", favoriteStopTags), moc: CoreDataStack.persistentContainer.viewContext) as? Array<Stop>
            {
                let sortedStopObjects = RouteDataManager.sortStopsByDistanceFromLocation(stops: stopObjects, locationToTest: location)
                
                let sortedStopTags = sortedStopObjects.map {$0.stopTag}
                favoriteStopObjects.sort(by: {
                    return (sortedStopTags.firstIndex(of: $0.stopTag) ?? 0) < (sortedStopTags.firstIndex(of: $1.stopTag) ?? 0)
                })
            }
            else
            {
                favoriteStopObjects.sort(by: {
                    if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", $0.stopTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop, let stop2 = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", $1.stopTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop
                    {
                        return stop.stopTitle!.compare(stop2.stopTitle!) == .orderedAscending
                    }
                    
                    return true
                })
            }
            
            self.favoriteStopObjects = favoriteStopObjects
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
        return favoriteStopObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let stopCell = tableView.dequeueReusableCell(withIdentifier: "StopCell")!
        
        let stopObject = favoriteStopObjects![indexPath.row]
        
        var textColor = UIColor.black
        if let route = RouteDataManager.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", FavoriteState.selectedRouteTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Route, let routeColor = route.routeColor, let routeOppositeColor = route.routeOppositeColor
        {
            stopCell.backgroundColor = UIColor(hexString: routeColor)
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        (stopCell.viewWithTag(600) as! UILabel).textColor = textColor
        (stopCell.viewWithTag(601) as! UILabel).textColor = textColor
        (stopCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", stopObject.stopTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop
        {
            (stopCell.viewWithTag(600) as! UILabel).text = stop.stopTitle
        }
        
        if let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", stopObject.directionTag ?? ""), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
        {
            (stopCell.viewWithTag(601) as! UILabel).text = direction.directionTitle
        }
        
        return stopCell
    }
    
    func fetchPrediction(favoriteStop: FavoriteStop, index: Int)
    {
        let predictionTimesReturnUUID = UUID().uuidString + ";" + String(index)
        NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStop.stopTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop, let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", favoriteStop.directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
        {
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
        }
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
            let favoriteStop = favoriteStopObjects![indexPath.row]
            
            fetchPrediction(favoriteStop: favoriteStop, index: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteStop = favoriteStopObjects![indexPath.row]
        
        MapState.selectedDirectionTag = favoriteStop.directionTag
        MapState.selectedStopTag = favoriteStop.stopTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedStopUnwind", sender: self)
    }
}
