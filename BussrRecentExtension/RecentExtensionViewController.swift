//
//  TodayViewController.swift
//  BussrRecentExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import NotificationCenter

class RecentExtensionViewController: MuniTrackerExtensionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loadRecentStops()
    }
    
    override func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
        super.widgetPerformUpdate(completionHandler: completionHandler)
        
        self.loadRecentStops()
    }
    
    func loadRecentStops()
    {
        if var recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: numStopsToDisplay) as? [RecentStop]
        {
            recentStops = recentStops.filter({ (recentStop) -> Bool in
                if recentStop.directionTag == nil || recentStop.stopTag == nil { return false }
                return RouteDataManager.fetchDirection(directionTag: recentStop.directionTag!) != nil && RouteDataManager.fetchStop(stopTag: recentStop.stopTag!) != nil
            })
            
            self.stopDirectionObjects = recentStops.map({ (recentStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: recentStop.stopTag!, directionTag: recentStop.directionTag!)
            })
        }
    }
}
