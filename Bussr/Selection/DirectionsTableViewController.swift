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
        
        if let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
        {
            mainNavigationItem.title = stop.title
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
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
                return $0.route!.tag!.compare($1.route!.tag!, options: .numeric) == .orderedAscending
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
                if let directionCell = directionsTableView.cellForRow(at: IndexPath(row: index, section: 0)) as? DirectionStopCell, let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
                {
                    directionCell.fetchPrediction(stopObject: stop, directionObject: direction)
                    self.loadedPredictions[index] = true
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            let direction = directionObjects![indexPath.row]
            if let stop = MapState.getCurrentStop()
            {
                (cell as! DirectionStopCell).fetchPrediction(stopObject: stop, directionObject: direction)
            }            
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return directionObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let directionCell = tableView.dequeueReusableCell(withIdentifier: "OtherDirectionCell") as! DirectionStopCell
        
        let directionCellBackground = UIView()
        directionCellBackground.backgroundColor = UIColor(white: 0.7, alpha: 0.4)
        directionCell.selectedBackgroundView = directionCellBackground
        
        let direction = directionObjects![indexPath.row]
        if let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
        {
            directionCell.directionObject = direction
            directionCell.stopObject = stop
            
            directionCell.updateCellText()
        }
        
        return directionCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let direction = directionObjects![indexPath.row]
        
        MapState.selectedDirectionTag = direction.tag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedDirectionUnwind", sender: self)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: unwindSegueID, sender: self)
    }
}
