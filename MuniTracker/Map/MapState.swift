//
//  MapState.swift
//  MuniTracker
//
//  Created by jackson on 6/20/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData

class MapState: NSObject
{
    enum RouteInfoType: Int
    {
        case none
        case direction
        case stop
        case otherDirections
        case vehicles
    }
    
    static var routeInfoShowing: RouteInfoType = .none
    static var routeInfoObject: Any? = nil
    
    static var selectedDirectionTag: String? = nil
    static var selectedStopTag: String? = nil
    static var selectedVehicleID: String? = nil
    
    static var showingPickerView = false
    
    static var currentRecentStopUUID: String? = nil
    
    static func getCurrentDirection() -> Direction?
    {
        if let route = MapState.routeInfoObject as? Route
        {
            let direction: Direction?
            if MapState.selectedDirectionTag != nil
            {
                direction = RouteDataManager.fetchObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", MapState.selectedDirectionTag!), moc: CoreDataStack.persistentContainer.viewContext) as? Direction
            }
            else
            {
                direction = route.directions?.array[0] as? Direction
            }
            
            return direction
        }
        else if MapState.selectedDirectionTag != nil
        {
            let direction = RouteDataManager.fetchObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", MapState.selectedDirectionTag!), moc: CoreDataStack.persistentContainer.viewContext) as? Direction
            return direction
        }
        
        return nil
    }
    
    static func getCurrentStop() -> Stop?
    {
        if MapState.selectedStopTag != nil
        {
            let stop = RouteDataManager.fetchStop(stopTag: MapState.selectedStopTag!)
            return stop
        }
        
        return nil
    }
}
