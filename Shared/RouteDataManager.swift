//
//  RouteDataManager.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData
import MapKit

let agencyTag = "sf-muni"

class RouteDataManager
{
    static var mocSaveGroup = DispatchGroup()
    
    //MARK: - Feed Source
    static let jsonFeedSource = "http://webservices.nextbus.com/service/publicJSONFeed"
    
    static func getJSONFromSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
        
        let task = (URLSession.shared.dataTask(with: URL(string: jsonFeedSource + "?command=" + command + commandString)!) { data, response, error in
            
            if data != nil, let json = try? JSONSerialization.jsonObject(with: data!) as? [String:Any]
            {
                callback(json)
            }
            else
            {
                callback(nil)
            }
        })
        
        task.resume()
    }
    
    //MARK: - Data Update
    
    static func updateAllData()
    {
        var routesFetched = 0
                
        let routeDictionary = fetchRoutes()
        print("Received Routes")
                
        CoreDataStack.persistentContainer.performBackgroundTask({ (backgroundMOC) in
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
            
            var routeConfigDirections: Array<Dictionary<String,Any>>?
            if route["direction"] is Array<Dictionary<String,Any>>
            {
                routeConfigDirections = route["direction"] as? Array<Dictionary<String, Any>>
            }
            else if route["direction"] is Dictionary<String,Any>
            {
                routeConfigDirections = [route["direction"]] as? Array<Dictionary<String, Any>>
            }
            
            for direction in routeConfigDirections ?? []
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
            
            routeInfoDictionary = Dictionary<String,Dictionary<String,Dictionary<String,Any>>>()
            routeInfoDictionary!["stops"] = routeStopsArray
            routeInfoDictionary!["directions"] = routeDirectionsArray
            routeInfoDictionary!["general"] = routeGeneralConfig
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeInfoDictionary!
    }
    
    //MARK: - Core Data
    
    static func fetchLocalObjects(type: String, predicate: NSPredicate, moc: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor]? = nil, fetchLimit: Int? = nil) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        fetchRequest.fetchLimit = fetchLimit ?? fetchRequest.fetchLimit
        
        var fetchResults: [AnyObject]?
        var error: NSError? = nil
        
        do {
            fetchResults = try moc.fetch(fetchRequest)
        } catch let error1 as NSError {
            error = error1
            fetchResults = nil
            print("An Error Occured: " + error!.localizedDescription)
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
    
    static func fetchObject(type: String, predicate: NSPredicate, moc: NSManagedObjectContext) -> NSManagedObject?
    {
        let objectFetchResults = fetchLocalObjects(type: type, predicate: predicate, moc: moc)
        if objectFetchResults != nil && objectFetchResults!.count > 0
        {
            return objectFetchResults?.first as? NSManagedObject
        }
        return nil
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
        
        if let favoriteStopCallback = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: predicate!, moc: CoreDataStack.persistentContainer.viewContext) //123 sort this by something
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
    
    static func fetchStop(stopTag: String, moc: NSManagedObjectContext? = nil) -> Stop?
    {
        return RouteDataManager.fetchObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", stopTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Stop
    }
    
    static func fetchDirection(directionTag: String, moc: NSManagedObjectContext? = nil) -> Direction?
    {
        return RouteDataManager.fetchObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", directionTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Direction
    }
    
    //MARK: - Data Fetch
    
    static let maxPredictions = 5
    static var fetchPredictionTimesOperations = Dictionary<String,BlockOperation>()
    static var fetchPredictionTimesReturnUUIDS = Dictionary<String,Array<String>>()
    
    static func fetchPredictionTimesForStop(returnUUID currentReturnUUID: String, stop: Stop?, direction: Direction?)
    {
        let directionStopID = (stop?.stopTag ?? "") + "-" + (direction?.directionTag ?? "")
        
        print("↓ - Fetching " + directionStopID + " Prediction Times")
        
        if (fetchPredictionTimesReturnUUIDS[directionStopID] == nil)
        {
            fetchPredictionTimesReturnUUIDS[directionStopID] = []
        }
        fetchPredictionTimesReturnUUIDS[directionStopID]?.append(currentReturnUUID)
        
        fetchPredictionTimesOperations[directionStopID]?.cancel()
        fetchPredictionTimesOperations[directionStopID] = BlockOperation()
        fetchPredictionTimesOperations[directionStopID]?.addExecutionBlock {
            DispatchQueue.global(qos: .background).async {
                if let stop = stop, let direction = direction, let route = direction.route
                {
                    getJSONFromSource("predictions", ["a":agencyTag,"s":stop.stopTag!,"r":route.routeTag!]) { (json) in
                        let directionStopID = (stop.stopTag ?? "") + "-" + (direction.directionTag ?? "")
                        
                        if let json = json
                        {
                            let predictionsMain = json["predictions"] as? Dictionary<String,Any> ?? [:]
                            
                            var directionDictionary: Dictionary<String,Any>?
                            
                            if let directionDictionaryTmp = predictionsMain["direction"] as? Dictionary<String,Any>
                            {
                                directionDictionary = directionDictionaryTmp
                            }
                            else if let directionArray = predictionsMain["direction"] as? Array<Dictionary<String,Any>>
                            {
                                for directionDictionaryTmp in directionArray
                                {
                                    if directionDictionaryTmp["title"] as? String == direction.directionTitle
                                    {
                                        directionDictionary = directionDictionaryTmp
                                        break
                                    }
                                }
                            }
                            
                            let predictionsDictionary = directionDictionary?["prediction"] as? Array<Dictionary<String,String>> ?? []
                            
                            var predictions = Array<String>()
                            var vehicles = Array<String>()
                            
                            for prediction in predictionsDictionary
                            {
                                predictions.append(prediction["minutes"] ?? "nil")
                                vehicles.append(prediction["vehicle"]!)
                            }
                            
                            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                            {
                                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictions,"vehicleIDs":vehicles])
                                                                
                                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
                            }
                        }
                        else
                        {
                            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                            {
                                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error"])
                                
                                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
                            }
                        }
                    }
                }
            }
        }
        
        fetchPredictionTimesOperations[directionStopID]?.start()
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
    
    static func fetchVehicleLocations(returnUUID: String, vehicleIDs: [String], direction: Direction?)
    {
        print("↓ - Fetching " + (direction?.directionTag ?? "") + " Locations")
        DispatchQueue.global(qos: .background).async {
            if let direction = direction, let route = direction.route
            {
                getJSONFromSource("vehicleLocations", ["a":agencyTag,"r":route.routeTag!,"t":lastVehicleTime ?? "0"]) { (json) in
                    guard let json = json else { return }
                    
                    let vehicles = json["vehicle"] as? Array<Dictionary<String,String>> ?? []
                    
                    var vehiclesInDirection = Array<(id: String, location: CLLocation, heading: Int)>()
                    
                    for vehicle in vehicles
                    {
                        if vehicleIDs.contains(vehicle["id"]!)
                        {
                            let id = vehicle["id"]!
                            let lat = Double(vehicle["lat"]!) ?? 0
                            let lon = Double(vehicle["lon"]!) ?? 0
                            let location = CLLocation(latitude: lat, longitude: lon)
                            let heading = Int(vehicle["heading"]!) ?? 0
                            
                            vehiclesInDirection.append((id: id, location: location, heading: heading))
                        }
                    }
                    
                    NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":vehiclesInDirection])
                }
            }
        }
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
