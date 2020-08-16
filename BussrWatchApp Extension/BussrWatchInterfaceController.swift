//
//  InterfaceController.swift
//  BussrWatchApp Extension
//
//  Created by jackson on 2/9/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import WatchKit
import Foundation


class BussrWatchInterfaceController: WKInterfaceController, CLLocationManagerDelegate {
    var directionStopObjects: Array<(stopTag: String, directionTag: String)>?
    var stops: Array<Stop>?
    
    let numStopsToDisplay = 10
    
    var currentUserLocation: CLLocation?
    var locationManager = CLLocationManager()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
    }
    
    var justLoaded = true
    
    override func willActivate() {
        if justLoaded
        {
            justLoaded = false
            NotificationCenter.default.addObserver(self, selector: #selector(loadStops), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            DispatchQueue.global(qos: .background).async
            {
                RouteDataManager.updateAllData()
            }
        }        
    }
    
    @objc func loadStops()
    {
        directionStopObjects = []
        if directionStopObjects?.count == 0 { setupMOCSaveNotification() }
    }
    
    func setupMOCSaveNotification()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(mocDidSave), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
    }
    
    @objc func mocDidSave()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        loadStops()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.first else { return }
        let oldUserLocation = currentUserLocation
        currentUserLocation = locations.first
        
        if oldUserLocation == nil || newLocation.distance(from: oldUserLocation!) >= 100
        {
            loadStops()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func updateTable(directionStopTable: WKInterfaceTable)
    {
        guard var directionStopObjects = self.directionStopObjects else { return }
        
        directionStopTable.setNumberOfRows(min(self.directionStopObjects?.count ?? 0, numStopsToDisplay), withRowType: "DirectionStopRow")
        if self.directionStopObjects?.count ?? 0 > numStopsToDisplay && self.directionStopObjects?.count ?? 0 > 0
        {
            directionStopObjects = Array<(stopTag: String, directionTag: String)>(directionStopObjects[0...numStopsToDisplay])
        }
        
        var directionStopOn = 0
        for directionStop in directionStopObjects
        {
            if let stop = RouteDataManager.fetchStop(stopTag: directionStop.stopTag), let direction = RouteDataManager.fetchDirection(directionTag: directionStop.directionTag), let directionStopRowController = directionStopTable.rowController(at: directionStopOn) as? DirectionStopRowController
            {
                directionStopRowController.directionStop = (stop: stop, direction: direction)
                
                directionStopRowController.updateCellText()
                directionStopRowController.startActivityIndicator()
                directionStopRowController.refreshTimes()
            }
            
            directionStopOn += 1
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if let directionStopRowController = table.rowController(at: rowIndex) as? DirectionStopRowController
        {
            directionStopRowController.predictionTimesLabel.setText("")
            directionStopRowController.startActivityIndicator()
            directionStopRowController.refreshTimes()
        }
    }
}
