//
//  InterfaceController.swift
//  MuniTrackerWatchApp Extension
//
//  Created by jackson on 2/9/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import WatchKit
import Foundation


class MuniTrackerWatchInterfaceController: WKInterfaceController {
    var directionStopObjects: Array<(stopTag: String, directionTag: String)>?
    var stops: Array<Stop>?
    
    let numStopsToDisplay = 4
    
    var directionStopTable: WKInterfaceTable?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func updateTable()
    {
        guard let directionStopTable = self.directionStopTable else { return }
        guard let directionStopObjects = self.directionStopObjects else { return }
        
        directionStopTable.setNumberOfRows(directionStopObjects.count, withRowType: "StopRow")
        
        var directionStopOn = 0
        for directionStop in directionStopObjects
        {
            if let stop = RouteDataManager.fetchStop(stopTag: directionStop.stopTag), let direction = RouteDataManager.fetchDirection(directionTag: directionStop.directionTag), let directionStopRowController = directionStopTable.rowController(at: directionStopOn) as? DirectionStopRowController
            {
                directionStopRowController.directionStop = (stop: stop, direction: direction)
                
                directionStopRowController.updateCellText()
                directionStopRowController.refreshTimes()
            }
            
            directionStopOn += 1
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        guard let directionStopTable = self.directionStopTable else { return }
        
        if let directionStopRowController = directionStopTable.rowController(at: rowIndex) as? DirectionStopRowController
        {
            directionStopRowController.refreshTimes()
        }
    }
}
