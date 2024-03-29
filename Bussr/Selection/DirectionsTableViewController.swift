//
//  StopInfoTableViewController.swift
//  Bussr
//
//  Created by jackson on 7/22/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class DirectionsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var stopTag: String?
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
        
        if let stopTag = stopTag, let stop = RouteDataManager.fetchStop(stopTag: stopTag)
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
        if let directions = directionObjects
        {
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
                if let directionCell = directionsTableView.cellForRow(at: IndexPath(row: index, section: 0)) as? DirectionStopCell
                {
                    directionCell.refreshTimes()
                    self.loadedPredictions[index] = true
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !loadedPredictions[indexPath.row]
        {
            (cell as! DirectionStopCell).refreshTimes(ignoreSetting: true)
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
        if let stopTag = stopTag, let stop = RouteDataManager.fetchStop(stopTag: stopTag)
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
        MapState.selectedStopTag = stopTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedDirectionUnwind", sender: self)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: unwindSegueID, sender: self)
    }
}
