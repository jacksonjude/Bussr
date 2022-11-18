//
//  RecentWatchInterfaceController.swift
//  BussrWatchApp Extension
//
//  Created by jackson on 8/15/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import Foundation
import WatchKit
import CoreLocation

class RecentWatchInterfaceController: BussrWatchInterfaceController
{
    @IBOutlet weak var stopsTable: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    @objc override func loadStops()
    {
        super.loadStops()
        loadRecentStops()
    }
    
    func loadRecentStops()
    {
        if var recentStops = CoreDataStack.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)], fetchLimit: numStopsToDisplay) as? [RecentStop]
        {
            recentStops = recentStops.filter({ (recentStop) -> Bool in
                if recentStop.directionTag == nil || recentStop.stopTag == nil { return false }
                return RouteDataManager.fetchDirection(directionTag: recentStop.directionTag!) != nil && RouteDataManager.fetchStop(stopTag: recentStop.stopTag!) != nil
            })
            
            self.directionStopObjects = recentStops.map({ (recentStop) -> (stopTag: String, directionTag: String) in
                return (stopTag: recentStop.stopTag!, directionTag: recentStop.directionTag!)
            })
            
            self.updateTable(directionStopTable: self.stopsTable)
        }
    }
}
