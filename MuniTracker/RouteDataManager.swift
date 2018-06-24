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

let agencyTag = "sf-muni"

class RouteDataManager
{
    enum RouteFetchType: Int {
        case routeList
        case routeConfig
        case predictionTimes
        case routeLocations
    }
    
    static let xmlFeedSource = "http://webservices.nextbus.com/service/publicXMLFeed"
    
    static func getXMLFromSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ xmlBody: XMLIndexer) -> Void)
    {
        var commandString = ""
        for commandArgument in arguments
        {
            commandString += "&" + commandArgument.key + "=" + commandArgument.value + "&"
        }
        
        _ = (URLSession.shared.dataTask(with: URL(string: xmlFeedSource + "?command=" + command + commandString)!) { data, response, error in
            let xml = SWXMLHash.parse(data!)
            let xmlBody = xml.children[0]
            callback(xmlBody)
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
                        
                        if stopFetchCallback.justCreated
                        {
                            direction.addToStops(stop)
                        }
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
                
                if routesFetched == routeDictionary.keys.count
                {
                    print("Complete")
                    
                    do
                    {
                        try backgroundMOC.save()
                    }
                    catch
                    {
                        print(error)
                    }
                    
                    OperationQueue.main.addOperation {
                        NotificationCenter.default.post(name: NSNotification.Name("FinishedUpdatingRoutes"), object: self)
                    }
                }
            
                try? backgroundMOC.save()
            }
        })
    }
    
    static func fetchRoutes() -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        
        backgroundGroup.enter()
        
        getXMLFromSource("routeList", ["a":agencyTag]) { (xmlBody) in
            routeDictionary = Dictionary<String,String>()
            
            for bodyChild in xmlBody.children
            {
                if bodyChild.element?.text != "\n"
                {
                    routeDictionary[(bodyChild.element?.allAttributes["tag"]?.text)!] = (bodyChild.element?.allAttributes["title"]?.text)!
                }
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
        
        getXMLFromSource("routeConfig", ["a":agencyTag,"r":routeTag,"terse":"618"]) { (xmlBody) in
            var routeDirectionsArray = Dictionary<String,Dictionary<String,Any>>()
            var routeStopsArray = Dictionary<String,Dictionary<String,String>>()
            var routeGeneralConfig = Dictionary<String,Dictionary<String,String>>()
            
            for bodyChild in xmlBody.children
            {
                if bodyChild.element?.text != "\n" && bodyChild.element?.name == "route"
                {
                    routeGeneralConfig["color"] = Dictionary<String,String>()
                    routeGeneralConfig["color"]!["color"] = bodyChild.element!.allAttributes["color"]!.text
                    routeGeneralConfig["color"]!["oppositeColor"] = bodyChild.element!.allAttributes["oppositeColor"]!.text
                    routeGeneralConfig["general"] = Dictionary<String,String>()
                    routeGeneralConfig["general"]!["shortTitle"] = bodyChild.element!.allAttributes["shortTitle"]?.text ?? bodyChild.element!.allAttributes["title"]!.text
                    
                    for routePart in bodyChild.children
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
                    }
                }
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
}
