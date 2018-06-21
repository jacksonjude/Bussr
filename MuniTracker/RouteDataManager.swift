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
    
    static func updateAllData(_ progressBar: UIProgressView...)
    {
        var routesFetched = 0
        
        //let backgroundMOC = appDelegate.persistentContainer.newBackgroundContext()
        
        let routeDictionary = fetchRoutes()
        print("Received Routes")
        
        let backgroundGroup = DispatchGroup()
        
        //backgroundGroup.enter()
        
        appDelegate.persistentContainer.performBackgroundTask({ (backgroundMOC) in
            let agency = fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "agencyName == %@", "sf-muni"), moc: backgroundMOC) as! Agency
            agency.agencyName = "sf-muni"
            
            //backgroundGroup.leave()
        
        //backgroundGroup.wait()
        
        for routeTitle in routeDictionary
        {
            //backgroundGroup.enter()
            
            //appDelegate.persistentContainer.performBackgroundTask({ (backgroundMOC) in
                let route = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", routeTitle.key), moc: backgroundMOC) as! Route
                route.routeTag = routeTitle.key
                route.routeTitle = routeTitle.value
                
                //backgroundGroup.leave()
            //})
            
            //backgroundGroup.wait()
            
            
            backgroundGroup.enter()
            
            fetchRouteInfo(routeTag: routeTitle.key, callback: { (routeConfig) in
                //appDelegate.persistentContainer.performBackgroundTask({ (backgroundMOC) in
                    //let agency = fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "agencyName == %@", "sf-muni"), moc: backgroundMOC) as! Agency
                    
                    let route = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", routeTitle.key), moc: backgroundMOC) as! Route
                    
                    print(routeTitle.key)
                    
                    let generalRouteConfig = routeConfig["general"]
                    route.routeColor = generalRouteConfig!["color"]!["color"] as? String
                    route.routeOppositeColor = generalRouteConfig!["color"]!["oppositeColor"] as? String
                    
                    for directionInfo in routeConfig["directions"]!
                    {
                        let direction = fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", directionInfo.key), moc: backgroundMOC) as! Direction
                        
                        direction.directionTag = directionInfo.value["tag"] as? String
                        direction.directionName = directionInfo.value["name"] as? String
                        direction.directionTitle = directionInfo.value["title"] as? String
                        
                        for directionStopTag in directionInfo.value["stops"] as! Array<String>
                        {
                            let stopConfig = routeConfig["stops"]![directionStopTag]
                            
                            let stop = fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", directionStopTag), moc: backgroundMOC) as! Stop
                            stop.stopTag = directionStopTag
                            stop.stopLatitude = Double(stopConfig!["lat"] as! String)!
                            stop.stopLongitude = Double(stopConfig!["lon"] as! String)!
                            stop.stopID = stopConfig!["stopId"] as? String
                            stop.stopTitle = stopConfig!["title"] as? String
                            stop.stopShortTitle = stopConfig!["shortTitle"] as? String
                            
                            direction.addToStops(stop)
                        }
                        
                        route.addToDirections(direction)
                    }
                    
                    agency.addToRoutes(route)
                    
                    routesFetched += 1
                    
                    if progressBar.count > 0
                    {
                        OperationQueue.main.addOperation {
                            progressBar[0].progress = Float(routesFetched)/Float(routeDictionary.keys.count)
                        }
                    }
                    
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
                    
                    backgroundGroup.leave()
                //})
            })
            
            backgroundGroup.wait()
        }
            
        })
    }
    
    static func fetchRoutes() -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        let backgroundGroup = DispatchGroup()
        
        backgroundGroup.enter()
        
        getXMLFromSource("routeList", ["a":"sf-muni"]) { (xmlBody) in
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
    
    static func fetchRouteInfo(routeTag: String, callback: @escaping (_ routeInfoDictionary: Dictionary<String,Dictionary<String,Dictionary<String,Any>>>) -> Void)
    {
        getXMLFromSource("routeConfig", ["a":"sf-muni","r":routeTag]) { (xmlBody) in
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
            
            var routeInfoDictionary = Dictionary<String,Dictionary<String,Dictionary<String,Any>>>()
            routeInfoDictionary["stops"] = routeStopsArray
            routeInfoDictionary["directions"] = routeDirectionsArray
            routeInfoDictionary["general"] = routeGeneralConfig
            
            callback(routeInfoDictionary)
        }
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
    
    static func fetchOrCreateObject(type: String, predicate: NSPredicate, moc: NSManagedObjectContext...) -> NSManagedObject
    {
        var mocToUse: NSManagedObjectContext?
        
        if moc.count > 0
        {
            mocToUse = moc[0]
        }
        else
        {
            mocToUse = appDelegate.persistentContainer.viewContext
        }
        
        let objectFetchResults = fetchLocalObjects(type: type, predicate: predicate, moc: mocToUse!)
        
        var object: NSManagedObject? = nil
        if objectFetchResults != nil && objectFetchResults!.count > 0
        {
            object = objectFetchResults?.first as? NSManagedObject
        }
        else
        {
            object = NSEntityDescription.insertNewObject(forEntityName: type, into: mocToUse!)
        }
        
        return object!
    }
}
