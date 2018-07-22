//
//  StopInfoTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 7/22/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class OtherDirectionTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var otherDirectionObjects: Array<Direction>?
    var loadedPredictions = Array<Bool>()
    @IBOutlet weak var otherDirectionsTableView: UITableView!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    
    override func viewDidLoad() {
        reloadTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(finishedCloudFetch(_:)), name: NSNotification.Name("FinishedFetchingFromCloud"), object: nil)
        CloudManager.fetchChangesFromCloud()
        
        setupThemeElements()
    }
    
    @objc func finishedCloudFetch(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        reloadTableView()
    }
    
    func reloadTableView()
    {
        fetchOtherDirectionObjects()
        sortOtherDirectionObjects()
        otherDirectionsTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        //let offWhite = UIColor(white: 0.97647, alpha: 1)
        let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = white
            self.mainNavigationBar.barTintColor = nil
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
        case .dark:
            self.view.backgroundColor = black
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        }
    }
    
    func fetchOtherDirectionObjects()
    {
        if let otherDirections = MapState.routeInfoObject as? Array<Direction>
        {
            otherDirectionObjects = otherDirections
            
            loadedPredictions = Array<Bool>()
            for _ in otherDirections
            {
                loadedPredictions.append(false)
            }
        }
    }
    
    func sortOtherDirectionObjects()
    {
        if var otherDirectionObjects = self.otherDirectionObjects
        {
            otherDirectionObjects.sort(by: {
                /*if let direction1 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $0.directionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction, let direction2 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $1.directionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction
                {
                    return direction1.route!.routeTag!.compare(direction2.route!.routeTag!, options: .numeric) == .orderedAscending
                }
                else
                {
                    return true
                }*/
                
                return $0.route!.routeTag!.compare($1.route!.routeTag!, options: .numeric) == .orderedAscending
            })
            
            self.otherDirectionObjects = otherDirectionObjects
        }
    }
    
    func fetchPredictionTimes()
    {
        if let otherDirections = self.otherDirectionObjects
        {
            for direction in otherDirections
            {
                let index = otherDirections.firstIndex(of: direction)!
                fetchPrediction(direction: direction, index: index)
            }
        }
    }
    
    func fetchPrediction(direction: Direction, index: Int)
    {
        let predictionTimesReturnUUID = UUID().uuidString + ";" + String(index)
        NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", MapState.selectedStopTag!), moc: appDelegate.persistentContainer.viewContext).object as? Stop
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
                let predictionsString = RouteDataManager.formatPredictions(predictions: predictions).predictionsString
                let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
                
                if let otherDirectionPredictionLabel = self.otherDirectionsTableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                {
                    self.loadedPredictions[indexRow] = true
                    otherDirectionPredictionLabel.text = predictionsString
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            let direction = otherDirectionObjects![indexPath.row]
            
            fetchPrediction(direction: direction, index: indexPath.row)
            /*NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", MapState.selectedStopTag!), moc: appDelegate.persistentContainer.viewContext).object as? Stop
            {
                RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
            }*/
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return otherDirectionObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let otherDirectionCell = tableView.dequeueReusableCell(withIdentifier: "OtherDirectionCell")!
        
        let direction = otherDirectionObjects![indexPath.row]
        
        var textColor = UIColor.black
        
        if let routeColor = direction.route?.routeColor, let routeOppositeColor = direction.route?.routeOppositeColor
        {
            otherDirectionCell.backgroundColor = UIColor(hexString: routeColor)
            
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        (otherDirectionCell.viewWithTag(601) as! UILabel).text = direction.directionTitle
        (otherDirectionCell.viewWithTag(600) as! UILabel).text = direction.route?.routeTag
        
        (otherDirectionCell.viewWithTag(601) as! UILabel).textColor = textColor
        (otherDirectionCell.viewWithTag(600) as! UILabel).textColor = textColor
        
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", MapState.selectedStopTag!), moc: appDelegate.persistentContainer.viewContext).object as? Stop
        {
            mainNavigationItem.title = stop.stopTitle
        }
        
        (otherDirectionCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        return otherDirectionCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let otherDirection = otherDirectionObjects![indexPath.row]
        
        MapState.selectedDirectionTag = otherDirection.directionTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = RouteDataManager.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedDirectionUnwind", sender: self)
    }
}
