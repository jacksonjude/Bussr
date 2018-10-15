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

class DirectionsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var directionObjects: Array<Direction>?
    var loadedPredictions = Array<Bool>()
    @IBOutlet weak var directionsTableView: UITableView!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    
    var unwindSegueID = "UnwindFromOtherDirection"
    
    override func viewDidLoad() {
        reloadTableView()
        
        setupThemeElements()
    }
    
    func reloadTableView()
    {
        fetchDirectionObjects()
        sortDirectionObjects()
        directionsTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
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
    
    func fetchDirectionObjects()
    {
        if let directions = MapState.routeInfoObject as? Array<Direction>
        {
            directionObjects = directions
            
            loadedPredictions = Array<Bool>()
            for _ in directions
            {
                loadedPredictions.append(false)
            }
        }
    }
    
    func sortDirectionObjects()
    {
        if var directionObjects = self.directionObjects
        {
            directionObjects.sort(by: {
                return $0.route!.routeTag!.compare($1.route!.routeTag!, options: .numeric) == .orderedAscending
            })
            
            self.directionObjects = directionObjects
        }
    }
    
    func fetchPredictionTimes()
    {
        if let directions = self.directionObjects
        {
            for direction in directions
            {
                let index = directions.firstIndex(of: direction)!
                fetchPrediction(direction: direction, index: index)
            }
        }
    }
    
    func fetchPrediction(direction: Direction, index: Int)
    {
        let predictionTimesReturnUUID = UUID().uuidString + ";" + String(index)
        NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        if let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
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
                
                if let directionPredictionLabel = self.directionsTableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                {
                    self.loadedPredictions[indexRow] = true
                    directionPredictionLabel.text = predictionsString
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            let direction = directionObjects![indexPath.row]
            
            fetchPrediction(direction: direction, index: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return directionObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let directionCell = tableView.dequeueReusableCell(withIdentifier: "OtherDirectionCell")!
        
        let direction = directionObjects![indexPath.row]
        
        var textColor = UIColor.black
        
        if let routeColor = direction.route?.routeColor, let routeOppositeColor = direction.route?.routeOppositeColor
        {
            directionCell.backgroundColor = UIColor(hexString: routeColor)
            
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        (directionCell.viewWithTag(601) as! UILabel).text = direction.directionTitle
        (directionCell.viewWithTag(600) as! UILabel).text = direction.route?.routeTag
        
        (directionCell.viewWithTag(601) as! UILabel).textColor = textColor
        (directionCell.viewWithTag(600) as! UILabel).textColor = textColor
        
        if let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
        {
            mainNavigationItem.title = stop.stopTitle
        }
        
        (directionCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        return directionCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let direction = directionObjects![indexPath.row]
        
        MapState.selectedDirectionTag = direction.directionTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedDirectionUnwind", sender: self)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: unwindSegueID, sender: self)
    }
}
