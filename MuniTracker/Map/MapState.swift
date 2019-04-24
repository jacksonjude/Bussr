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
                direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", MapState.selectedDirectionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
            }
            else
            {
                direction = route.directions?.array[0] as? Direction
            }
            
            return direction
        }
        else if MapState.selectedDirectionTag != nil
        {
            let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", MapState.selectedDirectionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
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
    
    static func formatPredictions(predictions: Array<String>, vehicleIDs: Array<String>? = nil) -> (predictionsString: String, selectedVehicleRange: NSRange?)
    {
        var predictionsString = ""
        var predictionOn = 0
        
        var selectedVehicleRange: NSRange?
        
        for prediction in predictions
        {
            if predictionOn != 0
            {
                predictionsString += ", "
            }
            
            if vehicleIDs != nil && vehicleIDs!.count > predictionOn && vehicleIDs![predictionOn] == MapState.selectedVehicleID && selectedVehicleRange == nil
            {
                selectedVehicleRange = NSRange(location: predictionsString.count, length: prediction.count)
            }
            
            if prediction == "0"
            {
                if selectedVehicleRange?.location == predictionsString.count
                {
                    selectedVehicleRange?.length = "Now".count
                }
                
                predictionsString += "Now"
            }
            else
            {
                predictionsString += prediction
            }
            
            predictionOn += 1
        }
        
        if predictions.count > 0
        {
            if predictions.count > 1 || predictions[0] != "0"
            {
                predictionsString += " mins"
            }
        }
        else
        {
            predictionsString = "No Predictions"
        }
        
        return (predictionsString, selectedVehicleRange)
    }
}
