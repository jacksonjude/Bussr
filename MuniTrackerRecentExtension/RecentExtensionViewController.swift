//
//  TodayViewController.swift
//  MuniTrackerRecentExtension
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
        if let recentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: numStopsToDisplay) as? [RecentStop]
        {
            self.stopDirectionObjects = recentStops.map({ (recentStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: recentStop.stopTag!, directionTag: recentStop.directionTag!)
            })
        }
    }
}
