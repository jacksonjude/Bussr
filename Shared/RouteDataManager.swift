//
//  RouteDataManager.swift
//  Bussr
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData
import MapKit
import BackgroundTasks
import Alamofire

struct RouteConstants
{
    static let NextBusAgencyTag = "sf-muni"
    static let nextBusJSONFeedSource = "https://retro.umoiq.com/service/publicJSONFeed"
    
    static let herokuHashSource = "http://munitracker.herokuapp.com"
    static let NextBusListHash = "/rlnextbushash"
    static let NextBusConfigHashes = "/rcnextbushash"
    static let BARTListHash = "/rlbarthash"
    static let BARTConfigHashes = "/rcbarthash"
    
    static let BARTAgencyTag = "BART"
    static let BARTJSONFeedSource = "http://api.bart.gov/api"
    static let BARTAPIKey = "Z7RK-596L-9WNT-DWE9"
}

enum ScheduledPredictionsDisplayType: Int
{
    case always
    case whenNeeded
    case never
}

class RouteDataManager
{
    static var mocSaveGroup = DispatchGroup()
    
    //MARK: - Feed Source
    
    static func getDataFromNextBusSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ data: Data?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
        
        AF.requestWithoutCache(RouteConstants.nextBusJSONFeedSource + "?command=" + command + commandString).response(queue: .global(qos: .background)) { response in
            if response.data != nil
            {
                callback(response.data)
            }
            else
            {
                callback(nil)
            }
        }
    }
    
    static var urlSessionDataTasks = Dictionary<String,URLSessionDataTask>()
    static var urlSessionTask: URLSessionDataTask?
    
    static func getJSONFromNextBusSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
        
        AF.requestWithoutCache(RouteConstants.nextBusJSONFeedSource + "?command=" + command + commandString).response(queue: .global(qos: .background)) { response in
            if response.data != nil, let json = try? JSONSerialization.jsonObject(with: response.data!) as? [String:Any]
            {
                callback(json)
            }
            else
            {
                callback(nil)
            }
        }
    }
    
    static func getDataFromBARTSource(_ path: String, _ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ data: Data?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
                
        let url = URL(string: RouteConstants.BARTJSONFeedSource + path + "?_=" + String(Date().timeIntervalSince1970) + "&cmd=" + command + commandString + "&json=y")!
        
        let task = (URLSession.shared.dataTask(with: url) { data, response, error in
            if data != nil
            {
                callback(data)
            }
            else
            {
                callback(nil)
            }
        })
        
        task.resume()
    }
    
    static func getJSONFromBARTSource(_ path: String, _ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value
        }
                
        let url = URL(string: RouteConstants.BARTJSONFeedSource + path + "?_=" + String(Date().timeIntervalSince1970) + "&cmd=" + command + commandString + "&json=y")!
        
        let task = (URLSession.shared.dataTask(with: url) { data, response, error in
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
    
    static var routesFetched = 0
    static var totalRoutes = 0
    
    static func updateAllData()
    {
        self.routesFetched = 0
        
        let NextBusRouteListHash = fetchRouteListHash(agencyTag: RouteConstants.NextBusAgencyTag)
        let NextBusRouteConfigHashes = fetchRouteConfigHashes(agencyTag: RouteConstants.NextBusAgencyTag)
        
        let NextBusRouteDictionary = fetchNextBusRoutes()
        let NextBusSortedRouteKeys = Array<String>(NextBusRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
        }
        print("Received NextBus Routes")
        
        let BARTRouteListHash = fetchRouteListHash(agencyTag: RouteConstants.BARTAgencyTag)
        let BARTRouteConfigHashes = fetchRouteConfigHashes(agencyTag: RouteConstants.BARTAgencyTag)
        
        let BARTRouteDictionary = fetchBARTRoutes()
        let BARTSortedRouteKeys = Array<String>(BARTRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
        }
        let BARTStopConfig = fetchBARTStops()
        print("Received BART Routes")
        
        self.totalRoutes = NextBusRouteDictionary.count + BARTRouteDictionary.count
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        self.loadRouteInfo(routeDictionary: NextBusRouteDictionary, sortedRouteKeys: NextBusSortedRouteKeys, agencyTag: RouteConstants.NextBusAgencyTag, listHash: NextBusRouteListHash, configHashes: NextBusRouteConfigHashes, mainBackgroundGroup: backgroundGroup, setRouteFields: { (routeKeyValue, backgroundMOC, configHashes, agencyTag) in
            let routeFetchCallback = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeKeyValue.tag), moc: backgroundMOC)
            let routeObject = routeFetchCallback.object as! Route
            
            routeObject.tag = routeKeyValue.tag
            routeObject.title = routeKeyValue.title
            
            if routeObject.serverHash == configHashes[routeKeyValue.tag] && configHashes[routeKeyValue.tag] != nil
            {
                routesFetched += 1
                checkForCompletedRoutes(routeTagOn: routeKeyValue.tag)
                
                return nil
            }
            else if configHashes.keys.contains(routeKeyValue.tag)
            {
                routeObject.serverHash = configHashes[routeKeyValue.tag]
            }
            
            print(agencyTag + " - " + routeKeyValue.tag)
            
            guard let routeConfig = fetchNextBusRouteInfo(routeTag: routeKeyValue.tag) else { return nil }
            
            routeObject.color = routeConfig.color
            routeObject.oppositeColor = routeConfig.oppositeColor
//            routeObject.scheduleJSON = routeConfig.scheduleJSON
            
            return (routeObject, routeFetchCallback.justCreated, routeConfig)
        })
        backgroundGroup.wait()
                
        self.loadRouteInfo(routeDictionary: BARTRouteDictionary, sortedRouteKeys: BARTSortedRouteKeys, agencyTag: RouteConstants.BARTAgencyTag, listHash: BARTRouteListHash, configHashes: BARTRouteConfigHashes, mainBackgroundGroup: nil) { (routeKeyValue, backgroundMOC, configHashes, agencyTag) -> (route: Route, justCreated: Bool, routeConfig: RouteConfiguation)? in
            var routeAbbr = routeKeyValue.title
            let routeNumber = routeKeyValue.tag

            let routeStartEnd = routeAbbr.split(separator: "-")
            let reverseRouteAbbr = String(routeStartEnd[1] + "-" + routeStartEnd[0])

            var tempRouteAbbr = routeAbbr
            var reverseRouteAbbrUsed = false
            var reverseRouteNumber: String?
            if BARTRouteDictionary.values.contains(reverseRouteAbbr)
            {
                reverseRouteNumber = BARTRouteDictionary.keys[BARTRouteDictionary.values.firstIndex(of: reverseRouteAbbr)!]
                reverseRouteAbbrUsed = routeNumber > reverseRouteNumber!
                tempRouteAbbr = routeNumber < reverseRouteNumber! ? routeAbbr : reverseRouteAbbr
            }

            if reverseRouteAbbrUsed
            {
                routesFetched += 1
                checkForCompletedRoutes(routeTagOn: RouteConstants.BARTAgencyTag + "-" + routeAbbr)

                return nil
            }

            let routeFetchCallback = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", RouteConstants.BARTAgencyTag + "-" + tempRouteAbbr), moc: backgroundMOC)
            let routeObject = routeFetchCallback.object as! Route
            
            let serverHash = routeObject.serverHash
            let serverHashSplit = serverHash?.split(separator: "-")
                        
            if serverHashSplit?.count == 2 && String(serverHashSplit?[reverseRouteAbbrUsed ? 1 : 0] ?? "") == configHashes[RouteConstants.BARTAgencyTag + "-" + routeNumber] && routeObject.directions?.array.count == 2 && configHashes[RouteConstants.BARTAgencyTag + "-" + routeNumber] != nil
            {
                routesFetched += 1
                checkForCompletedRoutes(routeTagOn: RouteConstants.BARTAgencyTag + "-" + routeAbbr)

                return nil
            }
            else if configHashes.keys.contains(RouteConstants.BARTAgencyTag + "-" + routeNumber)
            {
                let updatedHash = configHashes[RouteConstants.BARTAgencyTag + "-" + routeNumber] ?? " "
                if reverseRouteAbbrUsed
                {
                    let serverHash1 = serverHashSplit?.count ?? 0 >= 1 ? serverHashSplit![0] : " "
                    routeObject.serverHash = serverHash1 + "-" + updatedHash
                }
                else
                {
                    let serverHash2 = serverHashSplit?.count ?? 0 >= 2 ? serverHashSplit![1] : " "
                    routeObject.serverHash = updatedHash + "-" + serverHash2
                }
            }

            guard let routeConfig = fetchBARTRouteInfo(routeNumber: routeNumber) else {
                routesFetched += 1
                checkForCompletedRoutes(routeTagOn: RouteConstants.BARTAgencyTag + "-" + routeAbbr)
                
                return nil
            }
            print(agencyTag + " - " + routeAbbr)

            if BARTRouteDictionary.values.contains(reverseRouteAbbr)
            {
                let reverseRouteNumber = BARTRouteDictionary.keys[BARTRouteDictionary.values.firstIndex(of: reverseRouteAbbr)!]
                if let reverseRouteConfig = fetchBARTRouteInfo(routeNumber: reverseRouteNumber), let reverseRouteDirection = reverseRouteConfig.directions.first
                {
                    routeConfig.directions.append(reverseRouteDirection)
                }

                //Checking for ordering (lowest routeNumber)
                routeAbbr = routeNumber < reverseRouteNumber ? routeAbbr : reverseRouteAbbr
            }

            routeObject.tag = RouteConstants.BARTAgencyTag + "-" + routeAbbr
            routeObject.title = routeConfig.title
            
            routeObject.color = routeConfig.color
            routeObject.oppositeColor = routeConfig.oppositeColor
            
            if let stopArray = BARTStopConfig
            {
                try? routeConfig.loadStops(from: stopArray)
            }

            return (routeObject, routeFetchCallback.justCreated, routeConfig)
        }
    }
    
    static func loadRouteInfo(routeDictionary: Dictionary<String,String>, sortedRouteKeys: Array<String>, agencyTag: String, listHash: String, configHashes: Dictionary<String,String>, mainBackgroundGroup: DispatchGroup?, setRouteFields: @escaping (_ routeKeyValue: (tag: String, title: String), _ backgroundMOC: NSManagedObjectContext, _ configHashes: Dictionary<String,String>, _ agencyTag: String) -> (route: Route, justCreated: Bool, routeConfig: RouteConfiguation)?)
    {
        CoreDataStack.persistentContainer.performBackgroundTask({ (backgroundMOC) in
            let agencyFetchCallback = fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "name == %@", agencyTag), moc: backgroundMOC)
            let agency = agencyFetchCallback.object as! Agency
            agency.name = agencyTag
            if agency.serverHash != listHash
            {
                agency.serverHash = listHash
                if let routes = fetchLocalObjects(type: "Route", predicate: NSPredicate(format: "agency.name == %@", agencyTag), moc: backgroundMOC) as? [Route]
                {
                    for route in routes
                    {
                        if !sortedRouteKeys.contains(route.tag ?? "")
                        {
                            if let directions = route.directions?.array as? [Direction]
                            {
                                for direction in directions
                                {
                                    if let stops = direction.stops?.array as? [Stop]
                                    {
                                        for stop in stops
                                        {
                                            if stop.direction?.count ?? 0 <= 1
                                            {
                                                backgroundMOC.delete(stop)
                                            }
                                        }
                                    }
                                    
                                    backgroundMOC.delete(direction)
                                }
                            }
                            
                            backgroundMOC.delete(route)
                        }
                    }
                }
            }
            
            try? backgroundMOC.save()
            
            for routeTag in sortedRouteKeys
            {
                let routeTitle = routeDictionary[routeTag] ?? ""
                
                guard let routeFieldSetCallback = setRouteFields((tag: routeTag, title: routeTitle), backgroundMOC, configHashes, agency.name!) else { continue }
                
                let route = routeFieldSetCallback.route
                let routeJustCreated = routeFieldSetCallback.justCreated
                let routeConfig = routeFieldSetCallback.routeConfig
                
                var updatedDirections = Array<String>()
                
                for directionConfig in routeConfig.directions
                {
                    if directionConfig.stopTags.count == 0 { continue } // Not sure if this is needed
                    
                    let directionFetchCallback = fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", directionConfig.tag), moc: backgroundMOC)
                    let directionObject = directionFetchCallback.object as! Direction
                    
                    directionObject.tag = directionConfig.tag
                    directionObject.name = directionConfig.name
                    directionObject.title = directionConfig.title
                    
                    updatedDirections.append(directionObject.tag ?? "")
                    
                    if directionObject.stops?.count ?? 0 > 0
                    {
                        directionObject.removeFromStops(at: NSIndexSet(indexSet: IndexSet(integersIn: 0...directionObject.stops!.count-1)))
                    }
                    
                    for stopTagConfig in directionConfig.stopTags
                    {
                        guard let stopConfig = routeConfig.stops.first(where: { (stopConfig) -> Bool in
                            return stopConfig.tag == stopTagConfig.tag
                        }) else { continue }
                        
                        let stopFetchCallback = fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "tag == %@", stopConfig.tag), moc: backgroundMOC)
                        let stopObject = stopFetchCallback.object as! Stop
                        stopObject.tag = stopConfig.tag
                        stopObject.latitude = stopConfig.latitude
                        stopObject.longitude = stopConfig.longitude
                        stopObject.id = stopConfig.id
                        stopObject.title = stopConfig.title
                        stopObject.shortTitle = stopConfig.shortTitle
                        
                        directionObject.addToStops(stopObject)
                    }
                    
                    if directionFetchCallback.justCreated
                    {
                        route.addToDirections(directionObject)
                    }
                }
                
                if let directionObjects = fetchLocalObjects(type: "Direction", predicate: NSPredicate(format: "route.tag == %@", route.tag ?? ""), moc: backgroundMOC) as? [Direction]
                {
                    for direction in directionObjects
                    {
                        if !updatedDirections.contains(direction.tag ?? "")
                        {
                            backgroundMOC.delete(direction)
                        }
                    }
                }
                
                if routeJustCreated
                {
                    agency.addToRoutes(route)
                }
                
                mocSaveGroup.enter()
                NotificationCenter.default.addObserver(self, selector: #selector(savedBackgroundMOC), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                try? backgroundMOC.save()
                mocSaveGroup.wait()
                
                routesFetched += 1
                checkForCompletedRoutes(routeTagOn: (agencyTag == RouteConstants.BARTAgencyTag ? routeTitle : routeTag))
            }
            
            mainBackgroundGroup?.leave()
        })
    }
    
    @objc static func savedBackgroundMOC()
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        mocSaveGroup.leave()
    }
    
    static func checkForCompletedRoutes(routeTagOn: String)
    {
        NotificationCenter.default.post(name: NSNotification.Name("CompletedRoute"), object: self, userInfo: ["progress":Float(routesFetched)/Float(totalRoutes),"route":routeTagOn])
        
        if routesFetched == totalRoutes
        {
            print("Complete")
            UserDefaults.standard.set(Date(), forKey: "RoutesUpdatedAt")
            RouteDataManager.submitNextRouteUpdateBackgroundTask()
            
            OperationQueue.main.addOperation {
                NotificationCenter.default.post(name: NSNotification.Name("FinishedUpdatingRoutes"), object: self)
            }
        }
    }
    
    static func fetchNextBusRoutes() -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        getDataFromNextBusSource("routeList", ["a":RouteConstants.NextBusAgencyTag]) { (data) in
            guard let data = data else { return }
            
            let decoder = JSONDecoder()
            guard let routeList = try? decoder.decode(NextBusRouteList.self, from: data) else
            {
                backgroundGroup.leave()
                return
            }
            
            routeDictionary = Dictionary<String,String>()
            
            for route in routeList.routeObjects
            {
                routeDictionary[route.tag] = route.title
            }
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeDictionary
    }
    
    static func fetchRouteListHash(agencyTag: String) -> String
    {
        var routeListHash = ""

        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        let url = URL(string: RouteConstants.herokuHashSource + (agencyTag == RouteConstants.BARTAgencyTag ? RouteConstants.BARTListHash: RouteConstants.NextBusListHash) + "?_=" + String(Date().timeIntervalSince1970))!
        
        let task = (URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let listHash = String(data: data, encoding: .utf8)
            {
                routeListHash = listHash
            }
            
            backgroundGroup.leave()
        })
        
        task.resume()
        backgroundGroup.wait()
        
        return routeListHash
    }
    
    static func fetchRouteConfigHashes(agencyTag: String) -> [String:String]
    {
        var routeConfigHashes = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        let url = URL(string: RouteConstants.herokuHashSource + (agencyTag == RouteConstants.BARTAgencyTag ? RouteConstants.BARTConfigHashes: RouteConstants.NextBusConfigHashes) + "?_=" + String(Date().timeIntervalSince1970))!
        
        let task = (URLSession.shared.dataTask(with: url) { data, response, error in
            if data != nil, let json = try? JSONSerialization.jsonObject(with: data!) as? [String:String]
            {
                routeConfigHashes = json
            }
            
            backgroundGroup.leave()
        })
        
        task.resume()
        backgroundGroup.wait()
        
        return routeConfigHashes
    }
    
    static func fetchNextBusRouteInfo(routeTag: String) -> NextBusRouteConfiguration?
    {
        var routeConfiguration: NextBusRouteConfiguration?
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        getDataFromNextBusSource("routeConfig", ["a":RouteConstants.NextBusAgencyTag,"r":routeTag,"terse":"618"]) { (data) in
            guard let data = data else { return }
            
            let decoder = JSONDecoder()
            routeConfiguration = try? decoder.decode(NextBusRouteConfiguration.self, from: data)
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
//        backgroundGroup.enter()
//
//        getJSONFromNextBusSource("schedule", ["a":RouteConstants.NextBusAgencyTag,"r":routeTag]) { (json) in
//            do {
//                let jsonData = try JSONSerialization.data(withJSONObject: json ?? [:], options: JSONSerialization.WritingOptions.prettyPrinted)
//                let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
//                routeConfiguration?.scheduleJSON = jsonString
//            } catch let jsonError {
//                print(jsonError)
//            }
//
//            backgroundGroup.leave()
//        }
//
//        backgroundGroup.wait()
        
        return routeConfiguration
    }
    
    static func fetchBARTRoutes() -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        getDataFromBARTSource("/route.aspx", "routes", ["key":RouteConstants.BARTAPIKey]) { (data) in
            guard let data = data else { return }
            
            let decoder = JSONDecoder()
            guard let routeList = try? decoder.decode(BARTRouteList.self, from: data) else
            {
                backgroundGroup.leave()
                return
            }
            
            routeDictionary = Dictionary<String,String>()
                        
            for route in routeList.routeObjects
            {
                routeDictionary[route.number] = route.abbr
            }
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeDictionary
    }
    
    static func fetchBARTRouteInfo(routeNumber: String) -> BARTRouteConfiguration?
    {
        var routeConfiguration: BARTRouteConfiguration?
        
        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        getDataFromBARTSource("/route.aspx", "routeinfo", ["key":RouteConstants.BARTAPIKey,"route":routeNumber]) { (data) in
            guard let data = data else { return }
            
            let decoder = JSONDecoder()
            routeConfiguration = try? decoder.decode(BARTRouteConfiguration.self, from: data)
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        return routeConfiguration
    }
    
    static func fetchBARTStops() -> [BARTStopConfiguration]?
    {
        var stopArray: [BARTStopConfiguration]?

        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        getDataFromBARTSource("/stn.aspx", "stns", ["key":RouteConstants.BARTAPIKey]) { (data) in
            guard let data = data else { return }
            
            let decoder = JSONDecoder()
            let stopArrayContainer = try? decoder.decode(BARTStopArray.self, from: data)
            stopArray = stopArrayContainer?.stops
            
            backgroundGroup.leave()
        }

        backgroundGroup.wait()

        return stopArray
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
        
        if let favoriteStopCallback = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: predicate!, moc: CoreDataStack.persistentContainer.viewContext)
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
        return RouteDataManager.fetchObject(type: "Stop", predicate: NSPredicate(format: "tag == %@", stopTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Stop
    }
    
    static func fetchDirection(directionTag: String, moc: NSManagedObjectContext? = nil) -> Direction?
    {
        return RouteDataManager.fetchObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", directionTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Direction
    }
    
    //MARK: - Data Fetch
    
    enum PredictionTimeType
    {
        case exact
        case schedule
    }
    
    struct PredictionTime
    {
        var time: String
        var type: PredictionTimeType
        var vehicleID: String?
    }
    
    static var fetchPredictionTimesOperations = Dictionary<String,BlockOperation>()
    static var fetchPredictionTimesReturnUUIDS = Dictionary<String,Array<String>>()
    
    static func fetchPredictionTimesForStop(returnUUID currentReturnUUID: String, stop: Stop?, direction: Direction?)
    {
        let directionStopID = (stop?.tag ?? "") + "-" + (direction?.tag ?? "")
        
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
                if let stop = stop, let direction = direction, let route = direction.route, let agencyTag = route.agency?.name
                {
                    switch agencyTag
                    {
                    case RouteConstants.NextBusAgencyTag:
                        fetchNextBusPredictionTimes(route: route, direction: direction, stop: stop)
                    case RouteConstants.BARTAgencyTag:
                        fetchBARTPredictionTimes(route: route, direction: direction, stop: stop)
                    default:
                        break
                    }
                }
            }
        }
        
        fetchPredictionTimesOperations[directionStopID]?.start()
    }
    
    static func fetchNextBusPredictionTimes(route: Route, direction: Direction, stop: Stop)
    {
        let minimumExactPredictionsToAvoidScheduleFallback = 3
        
        getJSONFromNextBusSource("predictions", ["a":RouteConstants.NextBusAgencyTag,"s":stop.tag!,"r":route.tag!]) { (json) in
            let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
            
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
                    directionDictionary = Dictionary<String,Any>()
                    var predictionArray = Array<Dictionary<String,Any>>()
                    for directionDictionaryTmp in directionArray
                    {
                        if let predictionDictionary = directionDictionaryTmp["prediction"] as? Dictionary<String, Any>
                        {
                            predictionArray.append(predictionDictionary)
                        }
                        else if let predictionDictionaryArray = directionDictionaryTmp["prediction"] as? Array<Dictionary<String, Any>>
                        {
                            predictionArray.append(contentsOf: predictionDictionaryArray)
                        }
                    }
                    
                    directionDictionary?["prediction"] = predictionArray
                }
                
                var predictionsArray = directionDictionary?["prediction"] as? Array<Dictionary<String,String>> ?? []
                if let predictionDictionary = directionDictionary?["prediction"] as? Dictionary<String,String>
                {
                    predictionsArray = [predictionDictionary]
                }
                
                predictionsArray.sort { (prediction1, prediction2) -> Bool in
                    return Int(prediction1["minutes"] ?? "0") ?? 0 < Int(prediction2["minutes"] ?? "0") ?? 0
                }
                
                var predictions = Array<PredictionTime>()
                
                for prediction in predictionsArray
                {
                    predictions.append(PredictionTime(time: prediction["minutes"] ?? "nil", type: .exact, vehicleID: prediction["vehicle"]))
                }
                
                var shouldLoadSchedule = false
                
                if predictions.count < minimumExactPredictionsToAvoidScheduleFallback
                {
                    shouldLoadSchedule = true
                }
                
                let scheduledPredictionsDisplayType: ScheduledPredictionsDisplayType = (UserDefaults.standard.object(forKey: "ScheduledPredictions") as? Int).map { ScheduledPredictionsDisplayType(rawValue: $0)  ?? .whenNeeded } ?? .whenNeeded
                if scheduledPredictionsDisplayType == .always
                {
                    shouldLoadSchedule = true
                }
                
                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                {
                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictions, "willLoadSchedule": shouldLoadSchedule, "directionStopID": directionStopID])
                    
                    guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
                    
                    if !shouldLoadSchedule
                    {
                        fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
                    }
                }
                
                if shouldLoadSchedule
                {
                    fetchNextBusSchedulePredictionTimes(route: route, direction: direction, stop: stop, exactPredictions: predictions)
                }
            }
            else
            {
                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                {
                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error", "directionStopID": directionStopID])
                    
                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
                }
            }
        }
    }
    
    static func fetchNextBusSchedulePredictionTimes(route: Route, direction: Direction, stop: Stop, exactPredictions: Array<PredictionTime>?)
    {
        let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
        
        let scheduledPredictionsDisplayType: ScheduledPredictionsDisplayType = (UserDefaults.standard.object(forKey: "ScheduledPredictions") as? Int).map { ScheduledPredictionsDisplayType(rawValue: $0)  ?? .whenNeeded } ?? .whenNeeded
        if scheduledPredictionsDisplayType == .never
        {
            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
            {
                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
                
                guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
                
                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
            }
            return
        }
        
        let averageBusSpeed = 225.0 // Rough bus speed estimate in meters/minute
        let minPredictionTimeToIncludeSchedulesBefore = 25 // Schedule times will be excluded before the first prediction time if the that prediction is less than this value
        let scheduleToCurrentPredictionMarginOfError = 5 // Margin of error between scheduled time and exact time in minutes, so that a scheduled time can be excluded if a corresponding exact time is available
        
        let backgroundGroup = DispatchGroup()
        var routeScheduleJSON: [String : Any]?
        
        if let scheduleJSONData = route.schedule?.scheduleJSON, let expireDate = route.schedule?.expireDate, Date().compare(expireDate) == .orderedAscending
        {
            routeScheduleJSON = try? JSONSerialization.jsonObject(with: scheduleJSONData, options: .fragmentsAllowed) as? [String : Any]
        }
        else
        {
            backgroundGroup.enter()
            
            getJSONFromNextBusSource("schedule", ["a":RouteConstants.NextBusAgencyTag,"r":route.tag!]) { (json) in
                if let json = json
                {
                    routeScheduleJSON = json
                }
                else
                {
                    for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                    {
                        NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
                        
                        fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
                    }
                }
                
                backgroundGroup.leave()
            }
            
            backgroundGroup.wait()
            
            if let routeTag = route.tag, let routeScheduleJSON = routeScheduleJSON
            {
                CoreDataStack.persistentContainer.performBackgroundTask { backgroundMOC in
                    let routeScheduleCallback = fetchOrCreateObject(type: "RouteSchedule", predicate: NSPredicate(format: "route.tag == %@", routeTag), moc: backgroundMOC)
                    if let routeSchedule = routeScheduleCallback.object as? RouteSchedule
                    {
                        routeSchedule.scheduleJSON = try? JSONSerialization.data(withJSONObject: routeScheduleJSON, options: .fragmentsAllowed)
                        
                        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
                        dateComponents.hour = 0
                        dateComponents.minute = 0
                        let nextDay = Calendar.current.date(from: dateComponents)?.addingTimeInterval(60*60*24)
                        routeSchedule.expireDate = nextDay
                        
                        if routeScheduleCallback.justCreated, let routeObject = fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeTag), moc: backgroundMOC) as? Route
                        {
                            routeObject.schedule = routeSchedule
                        }
                    }
                    
                    do {
                        try backgroundMOC.save()
                    } catch let saveError {
                        print(saveError)
                    }
                }
            }
        }
        
        guard let routeScheduleJSON = routeScheduleJSON else
        {
            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
            {
                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
                
                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
            }
            return
        }
        
        let dayOfWeek = Calendar.current.dateComponents([.weekday], from: Date()).weekday
        var weekdayCode = ""
        switch dayOfWeek
        {
        case 1:
            weekdayCode = "sun"
        case 7:
            weekdayCode = "sat"
        default:
            weekdayCode = "wkd"
        }
        
        let dayComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        
        let currentEpochDayTime = 1000*(dayComponents.hour!*60*60+dayComponents.minute!*60+dayComponents.second!)
        var minEpochDayTime = currentEpochDayTime
        if scheduledPredictionsDisplayType != .always, let firstPredictionTimeString = exactPredictions?.first?.time, let firstPredictionTime = Int(firstPredictionTimeString), firstPredictionTime < minPredictionTimeToIncludeSchedulesBefore, let lastPredictionTimeString = exactPredictions?.last?.time, let lastPredictionTime = Int(lastPredictionTimeString)
        {
            minEpochDayTime = currentEpochDayTime + 1000*60*lastPredictionTime
        }
        let maxEpochDayTime = currentEpochDayTime + 1000*60*60
        
        let schedulesArray = routeScheduleJSON["route"] as? Array<Dictionary<String,Any>> ?? []
        var schedulePredictionMinutes = Array<(stopTag: String, minutes: Int)>()
        
        schedulesArray.forEach { scheduleDictionary in
            if scheduleDictionary["serviceClass"] as? String != weekdayCode { return }
            
            let scheduleBlocks = scheduleDictionary["tr"] as? Array<Dictionary<String,Any>> ?? []
            for scheduleBlock in scheduleBlocks
            {
                let scheduleStopsData = scheduleBlock["stop"] as? Array<Dictionary<String,String>> ?? []
                for stopData in scheduleStopsData
                {
                    if let stopTag = stopData["tag"], let epochTimeString = stopData["epochTime"], let epochTimeInt = Int(epochTimeString), epochTimeInt >= minEpochDayTime && epochTimeInt < maxEpochDayTime
                    {
                        schedulePredictionMinutes.append((stopTag: stopTag, minutes: (epochTimeInt-currentEpochDayTime)/1000/60))
                    }
                }
            }
        }
        
        backgroundGroup.enter()
        
        CoreDataStack.persistentContainer.performBackgroundTask { backgroundMOC in
            schedulePredictionMinutes = schedulePredictionMinutes.filter { stopMinutesTuple in
                if let stopObject = RouteDataManager.fetchStop(stopTag: stopMinutesTuple.stopTag, moc: backgroundMOC), let directionSet = stopObject.direction, directionSet.contains(where: { testDirection in
                    guard let testDirection = testDirection as? Direction else { return false }
                    
                    return testDirection.tag == direction.tag
                })
                {
                    guard var stops = direction.stops?.array as? [Stop] else { return false }
                    stops = stops.filter { testStop in
                        return stops.firstIndex { testStop2 in
                            return testStop2.tag == testStop.tag
                        } ?? 0 >= stops.firstIndex { testStop2 in
                            return testStop2.tag == stop.tag
                        } ?? 0
                    }
                    
                    return stops.contains { stop in
                        stop.tag == stopMinutesTuple.stopTag
                    }
                }
                
                return false
            }
            
            backgroundGroup.leave()
        }
        
        backgroundGroup.wait()
        
        schedulePredictionMinutes.sort { stopMinutesTuple1, stopMinutesTuple2 in
            guard let stops = direction.stops?.array as? [Stop] else { return false }
            
            return stops.firstIndex { testStop2 in
                return stopMinutesTuple1.stopTag == testStop2.tag
            } ?? 0 <= stops.firstIndex { testStop2 in
                return stopMinutesTuple2.stopTag == testStop2.tag
            } ?? 0
        }
        
        var schedulePredictionTimes = Array<PredictionTime>()
        if let firstStopTag = schedulePredictionMinutes.first?.stopTag, let nearestEarlyStop = RouteDataManager.fetchStop(stopTag: firstStopTag)
        {
            let nearestEarlyStopLocation = CLLocation(latitude: nearestEarlyStop.latitude, longitude: nearestEarlyStop.longitude)
            let currentStopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            
            let stopDistance = nearestEarlyStopLocation.distance(from: currentStopLocation)
            let minutesToAccountForDistance = Int(round(stopDistance / averageBusSpeed))
            
            schedulePredictionMinutes.forEach { stopMinutesTuple in
                if stopMinutesTuple.stopTag == firstStopTag
                {
                    let predictionMinutes = stopMinutesTuple.minutes-minutesToAccountForDistance
                    if predictionMinutes < 0 { return }
                    
                    for extactPredictionTime in exactPredictions ?? []
                    {
                        guard let exactPredictionMinutes = Int(extactPredictionTime.time) else { continue }
                        
                        let minPredictionTimeToExclude = exactPredictionMinutes-scheduleToCurrentPredictionMarginOfError
                        let maxPredictionTimeToExclude = exactPredictionMinutes+scheduleToCurrentPredictionMarginOfError
                        
                        if predictionMinutes >= minPredictionTimeToExclude && predictionMinutes <= maxPredictionTimeToExclude { return }
                    }
                        
                    schedulePredictionTimes.append(PredictionTime(time: String(predictionMinutes), type: .schedule))
                }
            }
        }
        
        var fullPredictionTimes = (schedulePredictionTimes+(exactPredictions ?? []))
        fullPredictionTimes.sort(by: { time1, time2 in
            Int(time1.time) ?? 0 < Int(time2.time) ?? 0
        })
        
        for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
        {
            NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":fullPredictionTimes, "directionStopID": directionStopID])
            
            guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
            
            fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
        }
    }
    
    static func fetchBARTPredictionTimes(route: Route, direction: Direction, stop: Stop)
    {
        getJSONFromBARTSource("/etd.aspx", "etd", ["key":RouteConstants.BARTAPIKey, "orig":stop.tag ?? ""]) { (json) in
            let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
            
            if let json = json
            {
                guard let routeHexColor = route.color else { return }
                
                guard let directionTag = direction.tag else { return }
                let directionTagSplit = directionTag.split(separator: "-")
                if directionTagSplit.count < 2 { return }
                let directionDestination = String(directionTagSplit[1])
                
                let predictionsMain = (json["root"] as? Dictionary<String,Any> ?? [:])["station"] as? Array<Dictionary<String,Any>> ?? []
                if predictionsMain.count < 1 { return }
                
                var predictionTimes = Array<PredictionTime>()
                if let etdArray = predictionsMain[0]["etd"] as? Array<Dictionary<String,Any>>
                {
                    for estimateTmp in etdArray
                    {
                        let destination = estimateTmp["abbreviation"] as? String
                        let estimateArray = estimateTmp["estimate"] as? Array<Dictionary<String,String>> ?? []
                        for estimate in estimateArray
                        {
                            guard var hexColor = estimate["hexcolor"] else { continue }
                            let hexColorSplit = hexColor.split(separator: "#")
                            if hexColorSplit.count < 1 { return }
                            hexColor = String(hexColorSplit[0])
                            
                            if directionDestination == destination && routeHexColor.lowercased() == hexColor.lowercased()
                            {
                                predictionTimes.append(PredictionTime(time: estimate["minutes"] ?? "nil", type: .exact))
                            }
                        }
                    }
                }
                
                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                {
                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictionTimes,"vehicleIDs":[], "directionStopID": directionStopID])
                    
                    guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
                    
                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
                }
            }
            else
            {
                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
                {
                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error", "directionStopID": directionStopID])
                    
                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
                }
            }
        }
    }
    
    static func sortStopsByDistanceFromLocation(stops: Array<Stop>, locationToTest: CLLocation) -> Array<Stop>
    {
        var distanceDictionary = Dictionary<Stop,Double>()
        
        for stop in stops
        {
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            distanceDictionary[stop] = locationToTest.distance(from: stopLocation)
        }
        
        let sortedStops = Array(distanceDictionary.keys).sorted(by: {distanceDictionary[$0]! < distanceDictionary[$1]!})
        
        return sortedStops
    }
    
    static var lastVehicleTime: String?
    
    static func fetchVehicleLocations(returnUUID: String, vehicleIDs: [String], direction: Direction?)
    {
        print("↓ - Fetching " + (direction?.tag ?? "") + " Locations")
        DispatchQueue.global(qos: .background).async {
            if let direction = direction, let route = direction.route, vehicleIDs.count > 0
            {
                getJSONFromNextBusSource("vehicleLocations", ["a":RouteConstants.NextBusAgencyTag,"r":route.tag!,"t":lastVehicleTime ?? "0"]) { (json) in
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
                    
                    NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":vehiclesInDirection, "direction": direction.tag ?? ""])
                }
            }
            else
            {
                NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":[], "direction": direction?.tag ?? ""])
            }
        }
    }
    
    static func formatPredictions(predictions: Array<PredictionTime>, predictionsToShow: Int = 5) -> NSAttributedString
    {
        var predictionsString = ""
        var predictionOn = 0
        
        var predictions = predictions
        if predictions.count > predictionsToShow && predictions.count > 0
        {
            predictions = Array<PredictionTime>(predictions[0...predictionsToShow-1])
        }
        
        var selectedVehicleRange: NSRange?
        
        var schedulePredictionRanges = Array<NSRange>()
        
        for prediction in predictions
        {
            if predictionOn != 0
            {
                predictionsString += ", "
            }
            
            if selectedVehicleRange == nil && prediction.vehicleID != nil && prediction.vehicleID == MapState.selectedVehicleID
            {
                selectedVehicleRange = NSRange(location: predictionsString.count, length: prediction.time.count)
            }
            else if prediction.type == .schedule
            {
                schedulePredictionRanges.append(NSRange(location: predictionsString.count, length: prediction.time.count))
            }
            
            if prediction.time == "0"
            {
                if selectedVehicleRange?.location == predictionsString.count
                {
                    selectedVehicleRange?.length = "Now".count
                }
                else if schedulePredictionRanges.last?.location == predictionsString.count
                {
                    schedulePredictionRanges[schedulePredictionRanges.count-1].length = "Now".count
                }
                
                predictionsString += "Now"
            }
            else
            {
                predictionsString += prediction.time
            }
            
            predictionOn += 1
        }
        
        if predictions.count > 0
        {
            if predictions.count > 1 || predictions[0].time != "0"
            {
                predictionsString += " mins"
            }
        }
        else
        {
            predictionsString = "No Predictions"
        }
        
        let predictionsAttributedString = NSMutableAttributedString(string: predictionsString, attributes: [:])
        if selectedVehicleRange != nil
        {
            predictionsAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(red: 0, green: 0.5, blue: 1, alpha: 1), range: selectedVehicleRange!)
        }
        for scheduleRange in schedulePredictionRanges
        {
            predictionsAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1), range: scheduleRange)
        }
        
        return predictionsAttributedString
    }
    
    static var currentRouteUpdateBackgroundTask: BGTask?
    
    static func executeRouteUpdateBackgroundTask(task: BGTask)
    {
        UserDefaults.standard.set(nil, forKey: "NextRouteUpdate")
        
        NotificationCenter.default.addObserver(self, selector: #selector(RouteDataManager.finishRouteUpdateBackgroundTask), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
        
        RouteDataManager.currentRouteUpdateBackgroundTask = task
        task.expirationHandler = {
            RouteDataManager.submitNextRouteUpdateBackgroundTask()
        }
        
        RouteDataManager.updateAllData()
    }
    
    @objc static func finishRouteUpdateBackgroundTask()
    {
        RouteDataManager.currentRouteUpdateBackgroundTask?.setTaskCompleted(success: true)
        RouteDataManager.currentRouteUpdateBackgroundTask = nil
        
        RouteDataManager.submitNextRouteUpdateBackgroundTask()
    }
    
    static func submitNextRouteUpdateBackgroundTask()
    {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.jacksonjude.Bussr.update_route_data")
        
        let lastRouteUpdate = UserDefaults.standard.object(forKey: "RoutesUpdatedAt") as? Date
        let nextRouteUpdate = lastRouteUpdate?.addingTimeInterval(60*60*20)
        
        let nextTaskRequest = BGProcessingTaskRequest(identifier: "com.jacksonjude.Bussr.update_route_data")
        nextTaskRequest.earliestBeginDate = nextRouteUpdate ?? Date() > Date() ? nextRouteUpdate : nil
        nextTaskRequest.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(nextTaskRequest)
        }
        catch {
            print(error.localizedDescription, error)
        }
        
        UserDefaults.standard.set(nextRouteUpdate ?? Date(), forKey: "NextRouteUpdate")
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

extension Alamofire.Session
{
    @discardableResult
    open func requestWithoutCache(
        _ url: URLConvertible,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil)// also you can add URLRequest.CachePolicy here as parameter
        -> DataRequest
    {
        do {
            var urlRequest = try URLRequest(url: url, method: method, headers: headers)
            urlRequest.cachePolicy = .reloadIgnoringCacheData // <<== Cache disabled
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return request(encodedURLRequest)
        } catch {
            print(error)
            return request("")
        }
    }
}
