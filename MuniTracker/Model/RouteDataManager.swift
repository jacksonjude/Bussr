//
//  RouteDataManager.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import SWXMLHash
import CoreData
import MapKit

let agencyTag = "sf-muni"

class RouteDataManager
{
    static var mocSaveGroup = DispatchGroup()
    
    enum RouteFetchType: Int {
        case routeList
        case routeConfig
        case predictionTimes
        case routeLocations
    }
    
    static let xmlFeedSource = "http://webservices.nextbus.com/service/publicXMLFeed"
    static let jsonFeedSource = "http://webservices.nextbus.com/service/publicJSONFeed"
    
    static func getXMLFromSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ xmlBody: XMLIndexer?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
        
        _ = (URLSession.shared.dataTask(with: URL(string: xmlFeedSource + "?command=" + command + commandString)!) { data, response, error in
            var xmlBody: XMLIndexer?
            if data != nil
            {
                let xml = SWXMLHash.parse(data!)
                xmlBody = xml.children[0]
            }
            callback(xmlBody)
        }).resume()
    }
    
    static func getJSONFromSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
        
        _ = (URLSession.shared.dataTask(with: URL(string: jsonFeedSource + "?command=" + command + commandString)!) { data, response, error in
            
            if data != nil, let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any]
            {
                callback(json)
            }
            
            callback(nil)
        }).resume()
    }
    
    static func updateAllData()
    {
        var routesFetched = 0
                
        let routeDictionary = fetchRoutes()
        print("Received Routes")
                
        appDelegate.persistentContainer.performBackgroundTask({ (backgroundMOC) in
            let agencyFetchCallback = fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "agencyName == %@", agencyTag), moc: backgroundMOC)
            let agency = agencyFetchCallback.object as! Agency
            agency.agencyName = agencyTag
        
            for routeTitle in routeDictionary
            {
                let routeFetchCallback = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", routeTitle.key), moc: backgroundMOC)
                let route = routeFetchCallback.object as! Route
                route.routeTag = routeTitle.key
                route.routeTitle = routeTitle.value
                
                let routeConfig = fetchRouteInfo(routeTag: routeTitle.key)
                
                print(routeTitle.key)
            
                let generalRouteConfig = routeConfig["general"]
                route.routeColor = generalRouteConfig!["color"]!["color"] as? String
                route.routeOppositeColor = generalRouteConfig!["color"]!["oppositeColor"] as? String
            
                for directionInfo in routeConfig["directions"]!
                {
                    let directionFetchCallback = fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", directionInfo.key), moc: backgroundMOC)
                    let direction = directionFetchCallback.object as! Direction
                    
                    direction.directionTag = directionInfo.key
                    direction.directionName = directionInfo.value["name"] as? String
                    direction.directionTitle = directionInfo.value["title"] as? String
                    
                    for directionStopTag in directionInfo.value["stops"] as! Array<String>
                    {
                        let stopConfig = routeConfig["stops"]![directionStopTag]
                        
                        let stopFetchCallback = fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", directionStopTag), moc: backgroundMOC)
                        let stop = stopFetchCallback.object as! Stop
                        stop.stopTag = directionStopTag
                        stop.stopLatitude = Double(stopConfig!["lat"] as! String)!
                        stop.stopLongitude = Double(stopConfig!["lon"] as! String)!
                        stop.stopID = stopConfig!["stopId"] as? String
                        stop.stopTitle = stopConfig!["title"] as? String
                        stop.stopShortTitle = stopConfig!["shortTitle"] as? String
                        
                        direction.addToStops(stop)
                    }
                    
                    if directionFetchCallback.justCreated
                    {
                        route.addToDirections(direction)
                    }
                }
                
                if routeFetchCallback.justCreated
                {
                    agency.addToRoutes(route)
                }
            
                routesFetched += 1
                
                NotificationCenter.default.post(name: NSNotification.Name("CompletedRoute"), object: self, userInfo: ["progress":Float(routesFetched)/Float(routeDictionary.keys.count)])
                
                mocSaveGroup.enter()
                
                NotificationCenter.default.addObserver(self, selector: #selector(savedBackgroundMOC), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                
                try? backgroundMOC.save()
                
                mocSaveGroup.wait()
                
                if routesFetched == routeDictionary.keys.count
                {
                    print("Complete")
                    
                    OperationQueue.main.addOperation {
                        NotificationCenter.default.post(name: NSNotification.Name("FinishedUpdatingRoutes"), object: self)
                    }
                }
            }
        })
    }
    
    @objc static func savedBackgroundMOC()
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        mocSaveGroup.leave()
    }
    
    static func fetchRoutes() -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        
        backgroundGroup.enter()
        
        getJSONFromSource("routeList", ["a":agencyTag]) { (json) in
            guard let json = json else { return }
            
            routeDictionary = Dictionary<String,String>()
            
            for route in json["route"] as? [Dictionary<String,String>] ?? []
            {
                routeDictionary[route["tag"]!] = route["title"]!
            }
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeDictionary
    }
    
    static func fetchRouteInfo(routeTag: String) -> Dictionary<String,Dictionary<String,Dictionary<String,Any>>>
    {
        var routeInfoDictionary: Dictionary<String,Dictionary<String,Dictionary<String,Any>>>?
        
        let backgroundGroup = DispatchGroup()
        
        backgroundGroup.enter()
        
        getJSONFromSource("routeConfig", ["a":agencyTag,"r":routeTag,"terse":"618"]) { (json) in
            guard let json = json else { return }
            
            var routeDirectionsArray = Dictionary<String,Dictionary<String,Any>>()
            var routeStopsArray = Dictionary<String,Dictionary<String,String>>()
            var routeGeneralConfig = Dictionary<String,Dictionary<String,String>>()
            
            let route = json["route"] as? Dictionary<String,Any> ?? [:]
            
            routeGeneralConfig["color"] = Dictionary<String,String>()
            routeGeneralConfig["color"]!["color"] = route["color"] as? String
            routeGeneralConfig["color"]!["oppositeColor"] = route["oppositeColor"] as? String
            routeGeneralConfig["general"] = Dictionary<String,String>()
            routeGeneralConfig["general"]!["shortTitle"] = route["shortTitle"] as? String ?? route ["title"] as! String
            
            for stop in route["stop"] as? Array<Dictionary<String,String>> ?? []
            {
                var routeStopDictionary = Dictionary<String,String>()
                let attributesToSet = ["title", "shortTitle", "lon", "lat", "stopId"]
                
                for attribute in attributesToSet
                {
                    routeStopDictionary[attribute] = stop[attribute]
                }
                
                routeStopsArray[stop["tag"]!] = routeStopDictionary
            }
            
            for direction in route["direction"] as? Array<Dictionary<String,Any>> ?? []
            {
                var routeDirectionDictionary = Dictionary<String,Any>()
                
                let attributesToSet = ["title", "name"]
                for attribute in attributesToSet
                {
                    routeDirectionDictionary[attribute] = direction[attribute]
                }
                
                var directionStops = Array<String>()
                for directionStop in direction["stop"] as? Array<Dictionary<String,String>> ?? []
                {
                    directionStops.append(directionStop["tag"]!)
                }
                
                routeDirectionDictionary["stops"] = directionStops
                
                routeDirectionsArray[direction["tag"] as! String] = routeDirectionDictionary
            }
            
            /*for routePart in bodyChild.children
            {
                if routePart.element?.text != "\n" && routePart.element?.name == "stop"
                {
                    var routeStopDictionary = Dictionary<String,String>()
                    
                    let attributesToSet = ["title", "shortTitle", "lon", "lat", "stopId"]
                    
                    for attribute in attributesToSet
                    {
                        routeStopDictionary[attribute] = routePart.element?.allAttributes[attribute]?.text
                    }
                    
                    routeStopsArray[routePart.element!.allAttributes["tag"]!.text] = routeStopDictionary
                }
                else if routePart.element?.text != "\n" && routePart.element?.name == "direction"
                {
                    var routeDirectionDictionary = Dictionary<String,Any>()
                    
                    let attributesToSet = ["title", "name"]
                    
                    for attribute in attributesToSet
                    {
                        routeDirectionDictionary[attribute] = routePart.element?.allAttributes[attribute]?.text
                    }
                    
                    var directionStops = Array<String>()
                    
                    for directionStop in routePart.children
                    {
                        if directionStop.element?.text != "\n" && directionStop.element?.name == "stop"
                        {
                            directionStops.append(directionStop.element!.allAttributes["tag"]!.text)
                        }
                    }
                    
                    routeDirectionDictionary["stops"] = directionStops
                    
                    routeDirectionsArray[routePart.element!.allAttributes["tag"]!.text] = routeDirectionDictionary
                }
            }*/
            
            routeInfoDictionary = Dictionary<String,Dictionary<String,Dictionary<String,Any>>>()
            routeInfoDictionary!["stops"] = routeStopsArray
            routeInfoDictionary!["directions"] = routeDirectionsArray
            routeInfoDictionary!["general"] = routeGeneralConfig
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeInfoDictionary!
    }
    
    static func fetchLocalObjects(type: String, predicate: NSPredicate, moc: NSManagedObjectContext) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        var fetchResults: [AnyObject]?
        var error: NSError? = nil
        
        do {
            fetchResults = try moc.fetch(fetchRequest)
        } catch let error1 as NSError {
            error = error1
            fetchResults = nil
            print("An Error Occored: " + error!.localizedDescription)
        } catch {
            fatalError()
        }
        
        return fetchResults
    }
    
    static func fetchOrCreateObject(type: String, predicate: NSPredicate, moc: NSManagedObjectContext) -> (object: NSManagedObject, justCreated: Bool)
    {
        let objectFetchResults = fetchLocalObjects(type: type, predicate: predicate, moc: moc)
        var justCreated = false
        
        var object: NSManagedObject? = nil
        if objectFetchResults != nil && objectFetchResults!.count > 0
        {
            object = objectFetchResults?.first as? NSManagedObject
        }
        else
        {
            object = NSEntityDescription.insertNewObject(forEntityName: type, into: moc)
            justCreated = true
        }
        
        return (object!, justCreated)
    }
    
    static func getCurrentDirection() -> Direction?
    {
        if let route = MapState.routeInfoObject as? Route
        {
            let direction: Direction?
            if MapState.selectedDirectionTag != nil
            {
                direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", MapState.selectedDirectionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction
            }
            else
            {
                direction = route.directions?.array[0] as? Direction
            }
            
            return direction
        }
        else if let direction = MapState.routeInfoObject as? Direction
        {
            return direction
        }
        
        return nil
    }
    
    static func getCurrentStop() -> Stop?
    {
        if MapState.selectedStopTag != nil
        {
            let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", MapState.selectedStopTag!), moc: appDelegate.persistentContainer.viewContext).object as? Stop
            return stop
        }
        
        return nil
    }
    
    static func fetchPredictionTimesForStop(returnUUID: String)
    {
        DispatchQueue.global(qos: .background).async {
            if let direction = getCurrentDirection(), let stop = getCurrentStop(), let route = direction.route
            {
                getXMLFromSource("predictions", ["a":agencyTag,"s":stop.stopTag!,"r":route.routeTag!]) { (xmlBody) in
                    if xmlBody != nil
                    {
                        for child in xmlBody!.children
                        {
                            if child.element?.text != "\n" && child.element?.name == "predictions"
                            {
                                var predictions = Array<String>()
                                var vehicles = Array<String>()
                                
                                for directionInfo in child.children
                                {
                                    for prediction in directionInfo.children
                                    {
                                        //if prediction.element?.allAttributes["dirTag"]?.text == direction.directionTag
                                        //{
                                            predictions.append(prediction.element?.allAttributes["minutes"]?.text ?? "nil")
                                        vehicles.append(prediction.element!.allAttributes["vehicle"]!.text)
                                        //}
                                    }
                                }
                                
                                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictions,"vehicleIDs":vehicles])
                            }
                        }
                    }
                    else
                    {
                        NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error"])
                    }
                }
            }
        }
    }
    
    static func sortStopsByDistanceFromLocation(stops: Array<Stop>, locationToTest: CLLocation) -> Array<Stop>
    {
        var distanceDictionary = Dictionary<Stop,Double>()
        
        for stop in stops
        {
            let stopLocation = CLLocation(latitude: stop.stopLatitude, longitude: stop.stopLongitude)
            distanceDictionary[stop] = locationToTest.distance(from: stopLocation)
        }
        
        let sortedStops = Array(distanceDictionary.keys).sorted(by: {distanceDictionary[$0]! < distanceDictionary[$1]!})
        
        return sortedStops
    }
    
    static var lastVehicleTime: String?
    
    static func fetchVehicleLocations(returnUUID: String, vehicleIDs: [String])
    {
        DispatchQueue.global(qos: .background).async {
            if let direction = getCurrentDirection(), let route = direction.route
            {
                getXMLFromSource("vehicleLocations", ["a":agencyTag,"r":route.routeTag!,"t":lastVehicleTime ?? "0"]) { (xmlBody) in
                    if xmlBody != nil
                    {
                        var vehiclesInDirection = Array<(id: String, location: CLLocation, heading: Int)>()
                        for child in xmlBody!.children
                        {
                            if child.element?.text != "\n" && child.element?.name == "vehicle"
                            {
                                //if child.element?.allAttributes["dirTag"]?.text == direction.directionTag
                                if vehicleIDs.contains(child.element!.allAttributes["id"]!.text)
                                //if true
                                {
                                    let id = child.element!.allAttributes["id"]!.text
                                    let lat = Double(child.element!.allAttributes["lat"]!.text) ?? 0
                                    let lon = Double(child.element!.allAttributes["lon"]!.text) ?? 0
                                    let location = CLLocation(latitude: lat, longitude: lon)
                                    let heading = Int(child.element!.allAttributes["heading"]!.text) ?? 0
                                    
                                    vehiclesInDirection.append((id: id, location: location, heading: heading))
                                }
                            }
                            else if child.element?.text != "\n" && child.element?.name == "lastTime"
                            {
                                //lastVehicleTime = child.element?.allAttributes["time"]?.text
                            }
                        }
                        
                        NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":vehiclesInDirection])
                    }
                }
            }
        }
    }
    
    static func fetchFavoriteStops(directionTag: String, stopTag: String? = nil) -> [FavoriteStop]
    {
        let predicate: NSPredicate?
        if stopTag != nil
        {
            predicate = NSPredicate(format: "stopTag == %@ && directionTag == %@", stopTag!, directionTag)
        }
        else
        {
            predicate = NSPredicate(format: "directionTag == %@", directionTag)
        }
        
        if let favoriteStopCallback = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: predicate!, moc: appDelegate.persistentContainer.viewContext)
        {
            return favoriteStopCallback as! [FavoriteStop]
        }
        
        return []
    }
    
    static func favoriteStopExists(stopTag: String, directionTag: String) -> Bool
    {
        let favoriteStopCallback = fetchFavoriteStops(directionTag: directionTag, stopTag: stopTag)
        if favoriteStopCallback.count > 0
        {
            return true
        }
        
        return false
    }
}

extension Dictionary
{
    func sortedKeysByValue() -> [Key]?
    {
        if let intDictionary = self as? [Key:Double]
        {
            var sortedArray = Array(intDictionary.keys)
            sortedArray.sort { (objectKey0, objectKey1) -> Bool in
                let obj1 = intDictionary[objectKey0] // get ob associated w/ key 1
                let obj2 = intDictionary[objectKey1] // get ob associated w/ key 2
                return obj1! > obj2!
            }
            
            return sortedArray
        }
        else
        {
            return nil
        }
    }
}
