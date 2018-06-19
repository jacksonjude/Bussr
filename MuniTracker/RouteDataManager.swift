//
//  RouteDataManager.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import Alamofire
import SWXMLHash
import CoreData

class RouteDataManager
{
    static let backgroundQueue = DispatchQueue(label: "background_queue")
    
    enum RouteFetchType: Int {
        case routeList
        case routeConfig
        case predictionTimes
        case routeLocations
    }
    
    static let xmlFeedSource = "http://webservices.nextbus.com/service/publicXMLFeed"
    static var fetchQueue = Dictionary<String,Array<Any>>()
    {
        didSet
        {
            initQueue()
        }
    }
    static var queueIsRunning = false
    
    static func addToQueue(returnUUID: String, fetchType: RouteFetchType, fetchInfo: Array<Any>)
    {
        
        var updatedFetchInfo = fetchInfo
        updatedFetchInfo.insert(fetchType, at: 0)
        fetchQueue[returnUUID] = updatedFetchInfo
    }
    
    static func initQueue()
    {
        if !queueIsRunning
        {
            queueIsRunning = true
            loopQueue()
        }
    }
    
    static func loopQueue()
    {
        if fetchQueue.keys.count > 0
        {
            let fetchType: RouteFetchType = fetchQueue.first?.value[0] as! RouteFetchType
            
            switch fetchType
            {
            case .routeList:
                //fetchRoutes()
                break
            default:
                break
            }
        }
        else
        {
            queueIsRunning = false
        }
    }
    
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
        
        /*Alamofire.request(URL(string: xmlFeedSource + "?command=" + command + commandString)!).responseData { (response) in
            //backgroundQueue.async
                //{
                    let xml = SWXMLHash.parse(response.result.value!)
                    let xmlBody = xml.children[0]
                    callback(xmlBody)
            //}
        }*/
    }
    
    static func updateAllData(_ progressBar: UIProgressView...)
    {
        /*let entityTypes = ["Agency", "Route", "Direction", "Stop"]
        
        for entityType in entityTypes
        {
            if let objects = self.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "TRUEPREDICATE")) as? [NSManagedObject]
            {
                for object in objects
                {
                    appDelegate.persistentContainer.viewContext.delete(object)
                }
            }
        }
        
        appDelegate.saveContext()*/
        
        let agency = fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "agencyName == %@", "sfmuni")) as! Agency
        
        var routesFetched = 0
        
        fetchRoutes { (routeDictionary) in
            for routeTitle in routeDictionary
            {
                let route = fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "routeTag == %@", routeTitle.key)) as! Route
                route.routeTag = routeTitle.key
                route.routeTitle = routeTitle.value
                
                fetchRouteInfo(routeTag: route.routeTag!, callback: { (routeConfig) in
                    print(routeTitle.key)
                    
                    for directionInfo in routeConfig["directions"]!
                    {
                        let direction = fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", directionInfo.key)) as! Direction
                        
                        direction.directionTag = directionInfo.value["tag"] as? String
                        direction.directionName = directionInfo.value["name"] as? String
                        direction.directionTitle = directionInfo.value["title"] as? String
                        
                        for directionStopTag in directionInfo.value["stops"] as! Array<String>
                        {
                            let stopConfig = routeConfig["stops"]![directionStopTag]
                            
                            let stop = fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", directionStopTag)) as! Stop
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
                    
                    appDelegate.saveContext()
                    
                    if routesFetched == routeDictionary.keys.count
                    {
                        print("Complete")
                        appDelegate.saveContext()
                    }
                })
            }
        }
    }
    
    static func fetchRoutes(callback: @escaping (_ routeDictionary: Dictionary<String,String>) -> Void)
    {
        getXMLFromSource("routeList", ["a":"sf-muni"]) { (xmlBody) in
            var routeDictionary = Dictionary<String,String>()
            
            for bodyChild in xmlBody.children
            {
                if bodyChild.element?.text != "\n"
                {
                    routeDictionary[(bodyChild.element?.allAttributes["tag"]?.text)!] = (bodyChild.element?.allAttributes["title"]?.text)!
                }
            }
            
            callback(routeDictionary)
        }
                        
        //NotificationCenter.default.post(name: NSNotification.Name("ParsedXML:" + self.fetchQueue.keys.first!), object: self, userInfo: ["xmlDictionary":routeDictionary])
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
            
            OperationQueue.main.addOperation {
                callback(routeInfoDictionary)
            }
        }
    }
    
    static func fetchLocalObjects(type: String, predicate: NSPredicate) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        var fetchResults: [AnyObject]?
        var error: NSError? = nil
        
        do {
            fetchResults = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
        } catch let error1 as NSError {
            error = error1
            fetchResults = nil
            print("An Error Occored: " + error!.localizedDescription)
        } catch {
            fatalError()
        }
        
        return fetchResults
    }
    
    static func fetchOrCreateObject(type: String, predicate: NSPredicate) -> NSManagedObject
    {
        let objectFetchResults = fetchLocalObjects(type: type, predicate: predicate)
        
        var object: NSManagedObject? = nil
        if objectFetchResults != nil && objectFetchResults!.count > 0
        {
            object = objectFetchResults?.first as? NSManagedObject
        }
        else
        {
            object = NSEntityDescription.insertNewObject(forEntityName: type, into: appDelegate.persistentContainer.viewContext)
        }
        
        return object!
    }
}
