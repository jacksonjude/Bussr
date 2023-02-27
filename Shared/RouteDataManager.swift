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

struct RouteConstants
{
//    static let NextBusAgencyTag = "sf-muni"
//    static let nextBusJSONFeedSource = "https://retro.umoiq.com/service/publicJSONFeed"
    
    static let herokuHashSource = "http://munitracker.herokuapp.com"
    static let NextBusListHash = "/rlnextbushash"
    static let NextBusConfigHashes = "/rcnextbushash"
    static let BARTListHash = "/rlbarthash"
    static let BARTConfigHashes = "/rcbarthash"
}

protocol APIFormat
{
    static var rootURL: String { get }
    static var apiKey: String { get }
    static var defaultAgencyTag: String { get }
    static var defaultArgs: Dictionary<String,String>? { get }
}

extension APIFormat
{
    static func getDefaultArgString() -> String
    {
        return self.defaultArgs?.reduce("", { partialResult, argumentPair in
            let (argName, argValue) = argumentPair
            return partialResult! + "&" + argName + "=" + argValue
        }) ?? ""
    }
}

struct UmoIQAPI: APIFormat
{
    static let rootURL = "https://webservices.umoiq.com/api/pub/v1"
    static let apiKey = "0be8ebd0284ce712a63f29dcaf7798c4"
    static let defaultAgencyTag = SFMTAAgencyTag
    static let defaultArgs: Dictionary<String, String>? = nil
    
    static let SFMTAAgencyTag = "sfmta-cis"
    
    static let agencyPath = APIPath(rawString: "/agencies/{agency}", arguments: ["agency"])
    static let routeListPath = APIPath(rawString: "/agencies/{agency}/routes", arguments: ["agency"])
    static let routeInfoPath = APIPath(rawString: "/agencies/{agency}/routes/{route}", arguments: ["agency", "route"])
    static let stopPredictionsPath = APIPath(rawString: "/agencies/{agency}/stops/{stop}/predictions", arguments: ["agency", "stop"])
    static let routeStopPredictionsPath = APIPath(rawString: "/agencies/{agency}/routes/{route}/stops/{stop}/predictions", arguments: ["agency", "route", "stop"])
    static let routeVehiclesPath = APIPath(rawString: "/agencies/{agency}/routes/{route}/vehicles", arguments: ["agency", "route"])
}

struct BARTAPI: APIFormat
{
    static let rootURL = "http://api.bart.gov/api"
    static let apiKey = "Z7RK-596L-9WNT-DWE9"
    static let defaultAgencyTag = BARTAgencyTag
    static let defaultArgs: Dictionary<String,String>? = ["json":"y"]
    
    static let BARTAgencyTag = "BART"
    
    static let routeListPath = APIPath(rawString: "/route.aspx?cmd=routes", arguments: [])
    static let routeInfoPath = APIPath(rawString: "/route.aspx?cmd=routeinfo&route={route}", arguments: ["route"])
    static let stopListPath = APIPath(rawString: "/stn.aspx?cmd=stns", arguments: [])
    static let predictionsPath = APIPath(rawString: "/etd.aspx?cmd=etd&orig={orig}", arguments: ["orig"])
}

class APIPath
{
    enum APIPathError: Error
    {
        case invalidArguments
    }
    
    var rawString: String
    var arguments: [String]
    
    init(rawString: String, arguments: [String])
    {
        self.rawString = rawString
        self.arguments = arguments
    }
    
    func format(_ argumentValues: [String : String]?) throws -> String
    {
        var formattedString = rawString
        for argumentName in arguments
        {
            guard let argumentValue = argumentValues?[argumentName] else { throw APIPathError.invalidArguments }
            formattedString = formattedString.replacingOccurrences(of:"{\(argumentName)}", with: argumentValue)
        }
        return formattedString
    }
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
    
    static func fetchFromAPISource<U: APIFormat, V: Decodable>(api: U.Type, path: APIPath, args: [String : String]?) async -> V?
    {
        guard let formattedURLPath = try? path.format(args) else { return nil }
        let defaultArgumentString = U.getDefaultArgString()
        guard let url = URL(string: U.rootURL + formattedURLPath + (formattedURLPath.contains("?") ? "&" : "?") + "key=\(U.apiKey)" + defaultArgumentString) else { return nil }
        
        let data: Data?
        do
        {
            (data, _) = try await URLSession.noCacheSession.data(from: url)
        }
        catch
        {
            print(error.localizedDescription)
            return nil
        }
        
        do
        {
            let decoder = JSONDecoder()
            return try decoder.decode(V.self, from: data!)
        }
        catch
        {
            print(error, url, String(bytes: data ?? Data(), encoding: .utf8) ?? "nil")
            return nil
        }
    }
    
//    static func getDataFromNextBusSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ data: Data?) -> Void)
//    {
//        var commandString = ""
//        for commandArgument in arguments
//        {
//            commandString += "&" + commandArgument.key + "=" + commandArgument.value
//        }
//
//        AF.requestWithoutCache(RouteConstants.nextBusJSONFeedSource + "?command=" + command + commandString).response(queue: .global(qos: .background)) { response in
//            if response.data != nil
//            {
//                callback(response.data)
//            }
//            else
//            {
//                callback(nil)
//            }
//        }
//    }
//
//    static func getJSONFromNextBusSource(_ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
//    {
//        var commandString = ""
//        for commandArgument in arguments
//        {
//            commandString += "&" + commandArgument.key + "=" + commandArgument.value
//        }
//
//        AF.requestWithoutCache(RouteConstants.nextBusJSONFeedSource + "?command=" + command + commandString).response(queue: .global(qos: .background)) { response in
//            if response.data != nil, let json = try? JSONSerialization.jsonObject(with: response.data!) as? [String:Any]
//            {
//                callback(json)
//            }
//            else
//            {
//                callback(nil)
//            }
//        }
//    }
    
//    static func getDataFromBARTSource(_ path: String, _ command: String, _ arguments: Dictionary<String,String>) async -> Data?
//    {
//        var commandString = ""
//        for commandArgument in arguments
//        {
//            commandString += "&" + commandArgument.key + "=" + commandArgument.value
//        }
//
//        let url = URL(string: RouteConstants.BARTJSONFeedSource + path + "?cmd=" + command + commandString + "&json=y")!
//
//        do
//        {
//            let (data, _) = try await URLSession.noCacheSession.data(from: url)
//            return data
//        }
//        catch { return nil }
//    }
    
//    static func getJSONFromBARTSource(_ path: String, _ command: String, _ arguments: Dictionary<String,String>, _ callback: @escaping (_ json: [String : Any]?) -> Void)
//    {
//        var commandString = ""
//        for commandArgument in arguments
//        {
//            commandString += "&" + commandArgument.key + "=" + commandArgument.value
//        }
//
//        let url = URL(string: RouteConstants.BARTJSONFeedSource + path + "?_=" + String(Date().timeIntervalSince1970) + "&cmd=" + command + commandString + "&json=y")!
//
//        let task = (URLSession.shared.dataTask(with: url) { data, response, error in
//            if data != nil, let json = try? JSONSerialization.jsonObject(with: data!) as? [String:Any]
//            {
//                callback(json)
//            }
//            else
//            {
//                callback(nil)
//            }
//        })
//
//        task.resume()
//    }
    
    //MARK: - Data Update
    
    static var routesFetched = 0
    static var routesSaved = 0
    static var totalRoutes = 0
    
    static func updateAllData() async
    {
        self.routesFetched = 0
        self.routesSaved = 0
        
        let UmoIQAgencyRevision = await fetchUmoIQAgencyRevision()
        let (UmoIQRouteDictionary, UmoIQRouteRevisions) = await fetchUmoIQRoutes()
        let UmoIQSortedRouteKeys = Array<String>(UmoIQRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
        }
        print("Received UmoIQ Routes")
                
//        let NextBusRouteListHash = fetchRouteListHash(agencyTag: RouteConstants.NextBusAgencyTag)
//        let NextBusRouteConfigHashes = fetchRouteConfigHashes(agencyTag: RouteConstants.NextBusAgencyTag)
//
//        let NextBusRouteDictionary = fetchNextBusRoutes()
//        let NextBusSortedRouteKeys = Array<String>(NextBusRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
//            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
//        }
//        print("Received NextBus Routes")
        
        let BARTRouteListHash = fetchRouteListHash(agencyTag: BARTAPI.BARTAgencyTag)
        let BARTRouteConfigHashes = fetchRouteConfigHashes(agencyTag: BARTAPI.BARTAgencyTag)
        
        let BARTRouteDictionary = await fetchBARTRoutes()
        let BARTSortedRouteKeys = Array<String>(BARTRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
        }
        let BARTStopConfig = await fetchBARTStops()
        print("Received BART Routes")
        
        self.totalRoutes = UmoIQRouteDictionary.count + BARTRouteDictionary.count
        
        await self.loadRouteInfo(routeDictionary: UmoIQRouteDictionary, sortedRouteKeys: UmoIQSortedRouteKeys, agencyTag: UmoIQAPI.SFMTAAgencyTag, listHash: UmoIQAgencyRevision, configHashes: UmoIQRouteRevisions, fetchRouteConfig: fetchUmoIQRouteInfo) { routeConfig, _, backgroundMOC, configHashes, agencyTag -> (route: Route, justCreated: Bool)? in
            let routeFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeConfig.tag), moc: backgroundMOC)
            let routeObject = routeFetchCallback.object as! Route

            routeObject.tag = routeConfig.tag
            routeObject.title = routeConfig.title

            if routeObject.serverHash == configHashes[routeConfig.tag] && configHashes[routeConfig.tag] != nil
            {
                routesSaved += 1
                checkForCompletedRoutes()

                return nil
            }
            else if configHashes.keys.contains(routeConfig.tag)
            {
                routeObject.serverHash = configHashes[routeConfig.tag]
            }

            print(agencyTag + " - " + routeConfig.tag)

            routeObject.color = routeConfig.color
            routeObject.oppositeColor = routeConfig.oppositeColor

            return (routeObject, routeFetchCallback.justCreated)
        }
        
//        let backgroundGroup = DispatchGroup()
//        backgroundGroup.enter()
//        self.loadRouteInfo(routeDictionary: NextBusRouteDictionary, sortedRouteKeys: NextBusSortedRouteKeys, agencyTag: RouteConstants.NextBusAgencyTag, listHash: NextBusRouteListHash, configHashes: NextBusRouteConfigHashes, mainBackgroundGroup: backgroundGroup, setRouteFields: { (routeKeyValue, backgroundMOC, configHashes, agencyTag) in
//            let routeFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeKeyValue.tag), moc: backgroundMOC)
//            let routeObject = routeFetchCallback.object as! Route
//
//            routeObject.tag = routeKeyValue.tag
//            routeObject.title = routeKeyValue.title
//
//            if routeObject.serverHash == configHashes[routeKeyValue.tag] && configHashes[routeKeyValue.tag] != nil
//            {
//                routesSaved += 1
//                checkForCompletedRoutes()
//
//                return nil
//            }
//            else if configHashes.keys.contains(routeKeyValue.tag)
//            {
//                routeObject.serverHash = configHashes[routeKeyValue.tag]
//            }
//
//            print(agencyTag + " - " + routeKeyValue.tag)
//
//            guard let routeConfig = fetchNextBusRouteInfo(routeTag: routeKeyValue.tag) else { return nil }
//
//            routeObject.color = routeConfig.color
//            routeObject.oppositeColor = routeConfig.oppositeColor
////            routeObject.scheduleJSON = routeConfig.scheduleJSON
//
//            return (routeObject, routeFetchCallback.justCreated, routeConfig)
//        })
//        backgroundGroup.wait()
                
        await self.loadRouteInfo(routeDictionary: BARTRouteDictionary, sortedRouteKeys: BARTSortedRouteKeys, agencyTag: BARTAPI.BARTAgencyTag, listHash: BARTRouteListHash, configHashes: BARTRouteConfigHashes, fetchRouteConfig: fetchBARTRouteInfo) { (routeConfig: inout RouteConfiguration, routeConfigurationDictionary, backgroundMOC, configHashes, agencyTag) -> (route: Route, justCreated: Bool)? in
            var routeAbbr = (routeConfig as! BARTRouteConfiguration).abbr
            let routeNumber = routeConfig.tag

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
                routesSaved += 1
                checkForCompletedRoutes()

                return nil
            }

            let routeFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", BARTAPI.BARTAgencyTag + "-" + tempRouteAbbr), moc: backgroundMOC)
            let routeObject = routeFetchCallback.object as! Route
            
            let serverHash = routeObject.serverHash
            let serverHashSplit = serverHash?.split(separator: "-")
                        
            if serverHashSplit?.count == 2 && String(serverHashSplit?[reverseRouteAbbrUsed ? 1 : 0] ?? "") == configHashes[BARTAPI.BARTAgencyTag + "-" + routeNumber] && routeObject.directions?.array.count == 2 && configHashes[BARTAPI.BARTAgencyTag + "-" + routeNumber] != nil
            {
                routesSaved += 1
                checkForCompletedRoutes()

                return nil
            }
            else if configHashes.keys.contains(BARTAPI.BARTAgencyTag + "-" + routeNumber)
            {
                let updatedHash = configHashes[BARTAPI.BARTAgencyTag + "-" + routeNumber] ?? " "
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

            print(agencyTag + " - " + routeAbbr)

            if BARTRouteDictionary.values.contains(reverseRouteAbbr)
            {
                let reverseRouteNumber = BARTRouteDictionary.keys[BARTRouteDictionary.values.firstIndex(of: reverseRouteAbbr)!]
                if let reverseRouteConfig = routeConfigurationDictionary[reverseRouteNumber], let reverseRouteDirection = reverseRouteConfig.directions.first
                {
                    routeConfig.directions.append(reverseRouteDirection)
                }

                //Checking for ordering (lowest routeNumber)
                routeAbbr = routeNumber < reverseRouteNumber ? routeAbbr : reverseRouteAbbr
            }

            routeObject.tag = BARTAPI.BARTAgencyTag + "-" + routeAbbr
            routeObject.title = routeConfig.title
            
            routeObject.color = routeConfig.color
            routeObject.oppositeColor = routeConfig.oppositeColor
            
            if let stopArray = BARTStopConfig
            {
                try? (routeConfig as! BARTRouteConfiguration).loadStops(from: stopArray)
            }

            return (routeObject, routeFetchCallback.justCreated)
        }
    }
    
    static func loadRouteInfo(routeDictionary: Dictionary<String,String>, sortedRouteKeys: Array<String>, agencyTag: String, listHash: String, configHashes: Dictionary<String,String>, fetchRouteConfig: (_ routeTag: String) async -> RouteConfiguration?, setRouteFields: @escaping (_ routeConfig: inout RouteConfiguration, _ routeConfigurationDictionary: Dictionary<String,RouteConfiguration>, _ backgroundMOC: NSManagedObjectContext, _ configHashes: Dictionary<String,String>, _ agencyTag: String) -> (route: Route, justCreated: Bool)?) async
    {
        var routeConfigurations = Dictionary<String,RouteConfiguration>()
        for routeTag in sortedRouteKeys
        {
            updateRouteFetchProgress(routeTagOn: routeTag)
            routesFetched += 1
            guard let routeConfig = await fetchRouteConfig(routeTag) else { continue }
            routeConfigurations[routeTag] = routeConfig
        }
        
        let backgroundMOC = CoreDataStack.persistentContainer.newBackgroundContext()
        await backgroundMOC.perform {
            let agencyFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Agency", predicate: NSPredicate(format: "name == %@", agencyTag), moc: backgroundMOC)
            let agency = agencyFetchCallback.object as! Agency
            agency.name = agencyTag
            if agency.serverHash != listHash
            {
                agency.serverHash = listHash
                if let routes = CoreDataStack.fetchLocalObjects(type: "Route", predicate: NSPredicate(format: "agency.name == %@", agencyTag), moc: backgroundMOC) as? [Route]
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
                guard var routeConfig = routeConfigurations[routeTag] else {
                    routesSaved += 1
                    checkForCompletedRoutes()
                    continue
                }
                guard let (route, routeJustCreated) = setRouteFields(&routeConfig, routeConfigurations, backgroundMOC, configHashes, agency.name!) else { continue }
                
                var updatedDirections = Array<String>()
                
                for directionConfig in routeConfig.directions
                {
                    if directionConfig.stopTags.count == 0 { continue } // Not sure if this is needed
                    if !directionConfig.useForUI { continue }
                    
                    let directionFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", directionConfig.tag), moc: backgroundMOC)
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
                        
                        let stopFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "tag == %@", stopConfig.tag), moc: backgroundMOC)
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
                
                if let directionObjects = CoreDataStack.fetchLocalObjects(type: "Direction", predicate: NSPredicate(format: "route.tag == %@", route.tag ?? ""), moc: backgroundMOC) as? [Direction]
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
                
                routesSaved += 1
                checkForCompletedRoutes()
            }
        }
    }
    
    @objc static func savedBackgroundMOC()
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        mocSaveGroup.leave()
    }
    
    static func updateRouteFetchProgress(routeTagOn: String)
    {
        NotificationCenter.default.post(name: NSNotification.Name("CompletedRoute"), object: self, userInfo: ["progress":Float(routesFetched)/Float(totalRoutes),"route":routeTagOn])
    }
    
    static func checkForCompletedRoutes()
    {
        if routesSaved == totalRoutes
        {
            print("Complete")
            UserDefaults.standard.set(Date(), forKey: "RoutesUpdatedAt")
            RouteDataManager.submitNextRouteUpdateBackgroundTask()
            
            OperationQueue.main.addOperation {
                NotificationCenter.default.post(name: NSNotification.Name("FinishedUpdatingRoutes"), object: self)
            }
        }
    }
    
    static func fetchUmoIQRoutes() async -> (routeDictionary: Dictionary<String, String>, routeRevisions: Dictionary<String, String>)
    {
        guard let routeIDs: [UmoIQRouteID] = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeListPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag]) else { return (Dictionary<String,String>(), Dictionary<String,String>()) }
        let routePairList = routeIDs.map({ routeID in
            return (routeID.tag, routeID.title)
        })
        let routeRevisionList = routeIDs.map({ routeID in
            return (routeID.tag, String(routeID.revision))
        })
                
        let routeDictionary = Dictionary<String,String>(routePairList) { first, _ in first }
        let routeRevisions = Dictionary<String,String>(routeRevisionList) { first, _ in first }
        
        return (routeDictionary: routeDictionary, routeRevisions: routeRevisions)
    }
    
    static func fetchUmoIQAgencyRevision() async -> String
    {
        guard let agency: UmoIQAgency = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.agencyPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag]) else { return "" }
        return String(agency.revision)
    }
    
    static func fetchUmoIQRouteInfo(routeTag: String) async -> UmoIQRouteConfiguration?
    {
        let routeConfiguration: UmoIQRouteConfiguration? = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeInfoPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag, "route":routeTag])
        return routeConfiguration
    }
    
//    static func fetchNextBusRoutes() -> Dictionary<String,String>
//    {
//        var routeDictionary = Dictionary<String,String>()
//
//        let backgroundGroup = DispatchGroup()
//        backgroundGroup.enter()
//
//        getDataFromNextBusSource("routeList", ["a":RouteConstants.NextBusAgencyTag]) { (data) in
//            guard let data = data else { return }
//
//            let decoder = JSONDecoder()
//            guard let routeList = try? decoder.decode(NextBusRouteList.self, from: data) else
//            {
//                backgroundGroup.leave()
//                return
//            }
//
//            routeDictionary = Dictionary<String,String>()
//
//            for route in routeList.routeObjects
//            {
//                routeDictionary[route.tag] = route.title
//            }
//
//            backgroundGroup.leave()
//        }
//
//        backgroundGroup.wait()
//
//        return routeDictionary
//    }
    
    static func fetchRouteListHash(agencyTag: String) -> String
    {
        var routeListHash = ""

        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        let url = URL(string: RouteConstants.herokuHashSource + (agencyTag == BARTAPI.BARTAgencyTag ? RouteConstants.BARTListHash: RouteConstants.NextBusListHash) + "?_=" + String(Date().timeIntervalSince1970))!
        
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
        
        let url = URL(string: RouteConstants.herokuHashSource + (agencyTag == BARTAPI.BARTAgencyTag ? RouteConstants.BARTConfigHashes: RouteConstants.NextBusConfigHashes) + "?_=" + String(Date().timeIntervalSince1970))!
        
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
    
//    static func fetchNextBusRouteInfo(routeTag: String) -> NextBusRouteConfiguration?
//    {
//        var routeConfiguration: NextBusRouteConfiguration?
//
//        let backgroundGroup = DispatchGroup()
//        backgroundGroup.enter()
//
//        getDataFromNextBusSource("routeConfig", ["a":RouteConstants.NextBusAgencyTag,"r":routeTag,"terse":"618"]) { (data) in
//            guard let data = data else { return }
//
//            let decoder = JSONDecoder()
//            routeConfiguration = try? decoder.decode(NextBusRouteConfiguration.self, from: data)
//
//            backgroundGroup.leave()
//        }
//
//        backgroundGroup.wait()
//
//        return routeConfiguration
//    }
    
    static func fetchBARTRoutes() async -> Dictionary<String,String>
    {
        var routeDictionary = Dictionary<String,String>()
        
        guard let routeList: BARTRouteList = await fetchFromAPISource(api: BARTAPI.self, path: BARTAPI.routeListPath, args: [:]) else { return routeDictionary }
        for route in routeList.routeObjects
        {
            routeDictionary[route.number] = route.abbr
        }
        
        return routeDictionary
    }
    
    static func fetchBARTRouteInfo(routeNumber: String) async -> BARTRouteConfiguration?
    {
        guard let routeConfiguration: BARTRouteConfiguration = await fetchFromAPISource(api: BARTAPI.self, path: BARTAPI.routeInfoPath, args: ["route":routeNumber]) else { return nil }
        return routeConfiguration
    }
    
    static func fetchBARTStops() async -> [BARTStopConfiguration]?
    {
        guard let stopArrayContainer: BARTStopArray = await fetchFromAPISource(api: BARTAPI.self, path: BARTAPI.stopListPath, args: [:]) else { return nil }
        
        let stopArray = stopArrayContainer.stops
        return stopArray
    }
    
    //MARK: - Core Data
    
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
        
        if let favoriteStopCallback = CoreDataStack.fetchLocalObjects(type: "FavoriteStop", predicate: predicate!, moc: CoreDataStack.persistentContainer.viewContext)
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
        return CoreDataStack.fetchObject(type: "Stop", predicate: NSPredicate(format: "tag == %@", stopTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Stop
    }
    
    static func fetchDirection(directionTag: String, moc: NSManagedObjectContext? = nil) -> Direction?
    {
        return CoreDataStack.fetchObject(type: "Direction", predicate: NSPredicate(format: "tag == %@", directionTag), moc: moc ?? CoreDataStack.persistentContainer.viewContext) as? Direction
    }
    
    //MARK: - Data Fetch
    
    static func fetchPredictionTimesForStop(stop: Stop?, direction: Direction?) async -> PredictionTimeFetchResult
    {
        guard let stop = stop, let direction = direction, let route = direction.route else { return .error(reason: "Invalid Route/Stop") }
        
        print("↓ - Fetching \(stop.tag ?? "")-\(direction.tag ?? "") Prediction Times")
        
        switch route.agency?.name
        {
        case UmoIQAPI.SFMTAAgencyTag:
            return await fetchUmoIQPredictionTimes(route: route, stop: stop)
        case BARTAPI.BARTAgencyTag:
            return await fetchBARTPredictionTimes(route: route, direction: direction, stop: stop)
        default:
            return .error(reason: "Invalid Agency")
        }
    }
    
    static func fetchUmoIQPredictionTimes(route: Route, stop: Stop) async -> PredictionTimeFetchResult
    {
        guard let routeStopPredictionContainers: Array<UmoIQRouteStopPredictionContainer> = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeStopPredictionsPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag, "route":route.tag!, "stop":stop.tag!]) else {
            return .error(reason: "Connection Error")
        }
        let predictionTimes = routeStopPredictionContainers.first?.predictions ?? []
        return .success(predictions: predictionTimes)
    }
    
//    static func fetchNextBusPredictionTimes(route: Route, direction: Direction, stop: Stop)
//    {
//        let minimumExactPredictionsToAvoidScheduleFallback = 3
//
//        getJSONFromNextBusSource("predictions", ["a":RouteConstants.NextBusAgencyTag,"s":stop.tag!,"r":route.tag!]) { (json) in
//            let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
//
//            if let json = json
//            {
//                let predictionsMain = json["predictions"] as? Dictionary<String,Any> ?? [:]
//
//                var directionDictionary: Dictionary<String,Any>?
//                if let directionDictionaryTmp = predictionsMain["direction"] as? Dictionary<String,Any>
//                {
//                    directionDictionary = directionDictionaryTmp
//                }
//                else if let directionArray = predictionsMain["direction"] as? Array<Dictionary<String,Any>>
//                {
//                    directionDictionary = Dictionary<String,Any>()
//                    var predictionArray = Array<Dictionary<String,Any>>()
//                    for directionDictionaryTmp in directionArray
//                    {
//                        if let predictionDictionary = directionDictionaryTmp["prediction"] as? Dictionary<String, Any>
//                        {
//                            predictionArray.append(predictionDictionary)
//                        }
//                        else if let predictionDictionaryArray = directionDictionaryTmp["prediction"] as? Array<Dictionary<String, Any>>
//                        {
//                            predictionArray.append(contentsOf: predictionDictionaryArray)
//                        }
//                    }
//
//                    directionDictionary?["prediction"] = predictionArray
//                }
//
//                var predictionsArray = directionDictionary?["prediction"] as? Array<Dictionary<String,String>> ?? []
//                if let predictionDictionary = directionDictionary?["prediction"] as? Dictionary<String,String>
//                {
//                    predictionsArray = [predictionDictionary]
//                }
//
//                predictionsArray.sort { (prediction1, prediction2) -> Bool in
//                    return Int(prediction1["minutes"] ?? "0") ?? 0 < Int(prediction2["minutes"] ?? "0") ?? 0
//                }
//
//                var predictions = Array<PredictionTime>()
//
//                for prediction in predictionsArray
//                {
//                    predictions.append(PredictionTime(time: prediction["minutes"] ?? "nil", type: .exact, vehicleID: prediction["vehicle"]))
//                }
//
//                var shouldLoadSchedule = false
//
//                if predictions.count < minimumExactPredictionsToAvoidScheduleFallback
//                {
//                    shouldLoadSchedule = true
//                }
//
//                let scheduledPredictionsDisplayType: ScheduledPredictionsDisplayType = (UserDefaults.standard.object(forKey: "ScheduledPredictions") as? Int).map { ScheduledPredictionsDisplayType(rawValue: $0)  ?? .whenNeeded } ?? .whenNeeded
//                if scheduledPredictionsDisplayType == .always
//                {
//                    shouldLoadSchedule = true
//                }
//
//                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//                {
//                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictions, "willLoadSchedule": shouldLoadSchedule, "directionStopID": directionStopID])
//
//                    guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
//
//                    if !shouldLoadSchedule
//                    {
//                        fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
//                    }
//                }
//
//                if shouldLoadSchedule
//                {
//                    fetchNextBusSchedulePredictionTimes(route: route, direction: direction, stop: stop, exactPredictions: predictions)
//                }
//            }
//            else
//            {
//                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//                {
//                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error", "directionStopID": directionStopID])
//
//                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
//                }
//            }
//        }
//    }
    
//    static func fetchNextBusSchedulePredictionTimes(route: Route, direction: Direction, stop: Stop, exactPredictions: Array<PredictionTime>?)
//    {
//        let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
//
//        let scheduledPredictionsDisplayType: ScheduledPredictionsDisplayType = (UserDefaults.standard.object(forKey: "ScheduledPredictions") as? Int).map { ScheduledPredictionsDisplayType(rawValue: $0)  ?? .whenNeeded } ?? .whenNeeded
//        if scheduledPredictionsDisplayType == .never
//        {
//            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//            {
//                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
//
//                guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
//
//                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
//            }
//            return
//        }
//
//        let averageBusSpeed = 225.0 // Rough bus speed estimate in meters/minute
//        let minPredictionTimeToIncludeSchedulesBefore = 25 // Schedule times will be excluded before the first prediction time if the that prediction is less than this value
//        let scheduleToCurrentPredictionMarginOfError = 5 // Margin of error between scheduled time and exact time in minutes, so that a scheduled time can be excluded if a corresponding exact time is available
//
//        let backgroundGroup = DispatchGroup()
//        var routeScheduleJSON: [String : Any]?
//
//        if let scheduleJSONData = route.schedule?.scheduleJSON, let expireDate = route.schedule?.expireDate, Date().compare(expireDate) == .orderedAscending
//        {
//            routeScheduleJSON = try? JSONSerialization.jsonObject(with: scheduleJSONData, options: .fragmentsAllowed) as? [String : Any]
//        }
//        else
//        {
//            backgroundGroup.enter()
//
//            getJSONFromNextBusSource("schedule", ["a":RouteConstants.NextBusAgencyTag,"r":route.tag!]) { (json) in
//                if let json = json
//                {
//                    routeScheduleJSON = json
//                }
//                else
//                {
//                    for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//                    {
//                        NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
//
//                        fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
//                    }
//                }
//
//                backgroundGroup.leave()
//            }
//
//            backgroundGroup.wait()
//
//            if let routeTag = route.tag, let routeScheduleJSON = routeScheduleJSON
//            {
//                CoreDataStack.persistentContainer.performBackgroundTask { backgroundMOC in
//                    let routeScheduleCallback = CoreDataStack.fetchOrCreateObject(type: "RouteSchedule", predicate: NSPredicate(format: "route.tag == %@", routeTag), moc: backgroundMOC)
//                    if let routeSchedule = routeScheduleCallback.object as? RouteSchedule
//                    {
//                        routeSchedule.scheduleJSON = try? JSONSerialization.data(withJSONObject: routeScheduleJSON, options: .fragmentsAllowed)
//
//                        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
//                        dateComponents.hour = 0
//                        dateComponents.minute = 0
//                        let nextDay = Calendar.current.date(from: dateComponents)?.addingTimeInterval(60*60*24)
//                        routeSchedule.expireDate = nextDay
//
//                        if routeScheduleCallback.justCreated, let routeObject = CoreDataStack.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeTag), moc: backgroundMOC) as? Route
//                        {
//                            routeObject.schedule = routeSchedule
//                        }
//                    }
//
//                    do {
//                        try backgroundMOC.save()
//                    } catch let saveError {
//                        print(saveError)
//                    }
//                }
//            }
//        }
//
//        guard let routeScheduleJSON = routeScheduleJSON else
//        {
//            for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//            {
//                NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":exactPredictions ?? [], "directionStopID": directionStopID])
//
//                fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
//            }
//            return
//        }
//
//        let dayOfWeek = Calendar.current.dateComponents([.weekday], from: Date()).weekday
//        var weekdayCode = ""
//        switch dayOfWeek
//        {
//        case 1:
//            weekdayCode = "sun"
//        case 7:
//            weekdayCode = "sat"
//        default:
//            weekdayCode = "wkd"
//        }
//
//        let dayComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
//
//        let currentEpochDayTime = 1000*(dayComponents.hour!*60*60+dayComponents.minute!*60+dayComponents.second!)
//        var minEpochDayTime = currentEpochDayTime
//        if scheduledPredictionsDisplayType != .always, let firstPredictionTimeString = exactPredictions?.first?.time, let firstPredictionTime = Int(firstPredictionTimeString), firstPredictionTime < minPredictionTimeToIncludeSchedulesBefore, let lastPredictionTimeString = exactPredictions?.last?.time, let lastPredictionTime = Int(lastPredictionTimeString)
//        {
//            minEpochDayTime = currentEpochDayTime + 1000*60*lastPredictionTime
//        }
//        let maxEpochDayTime = currentEpochDayTime + 1000*60*60
//
//        let schedulesArray = routeScheduleJSON["route"] as? Array<Dictionary<String,Any>> ?? []
//        var schedulePredictionMinutes = Array<(stopTag: String, minutes: Int)>()
//
//        schedulesArray.forEach { scheduleDictionary in
//            if scheduleDictionary["serviceClass"] as? String != weekdayCode { return }
//
//            let scheduleBlocks = scheduleDictionary["tr"] as? Array<Dictionary<String,Any>> ?? []
//            for scheduleBlock in scheduleBlocks
//            {
//                let scheduleStopsData = scheduleBlock["stop"] as? Array<Dictionary<String,String>> ?? []
//                for stopData in scheduleStopsData
//                {
//                    if let stopTag = stopData["tag"], let epochTimeString = stopData["epochTime"], let epochTimeInt = Int(epochTimeString), epochTimeInt >= minEpochDayTime && epochTimeInt < maxEpochDayTime
//                    {
//                        schedulePredictionMinutes.append((stopTag: stopTag, minutes: (epochTimeInt-currentEpochDayTime)/1000/60))
//                    }
//                }
//            }
//        }
//
//        backgroundGroup.enter()
//
//        CoreDataStack.persistentContainer.performBackgroundTask { backgroundMOC in
//            schedulePredictionMinutes = schedulePredictionMinutes.filter { stopMinutesTuple in
//                if let stopObject = RouteDataManager.fetchStop(stopTag: stopMinutesTuple.stopTag, moc: backgroundMOC), let directionSet = stopObject.direction, directionSet.contains(where: { testDirection in
//                    guard let testDirection = testDirection as? Direction else { return false }
//
//                    return testDirection.tag == direction.tag
//                })
//                {
//                    guard var stops = direction.stops?.array as? [Stop] else { return false }
//                    stops = stops.filter { testStop in
//                        return stops.firstIndex { testStop2 in
//                            return testStop2.tag == testStop.tag
//                        } ?? 0 >= stops.firstIndex { testStop2 in
//                            return testStop2.tag == stop.tag
//                        } ?? 0
//                    }
//
//                    return stops.contains { stop in
//                        stop.tag == stopMinutesTuple.stopTag
//                    }
//                }
//
//                return false
//            }
//
//            backgroundGroup.leave()
//        }
//
//        backgroundGroup.wait()
//
//        schedulePredictionMinutes.sort { stopMinutesTuple1, stopMinutesTuple2 in
//            guard let stops = direction.stops?.array as? [Stop] else { return false }
//
//            return stops.firstIndex { testStop2 in
//                return stopMinutesTuple1.stopTag == testStop2.tag
//            } ?? 0 <= stops.firstIndex { testStop2 in
//                return stopMinutesTuple2.stopTag == testStop2.tag
//            } ?? 0
//        }
//
//        var schedulePredictionTimes = Array<PredictionTime>()
//        if let firstStopTag = schedulePredictionMinutes.first?.stopTag, let nearestEarlyStop = RouteDataManager.fetchStop(stopTag: firstStopTag)
//        {
//            let nearestEarlyStopLocation = CLLocation(latitude: nearestEarlyStop.latitude, longitude: nearestEarlyStop.longitude)
//            let currentStopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
//
//            let stopDistance = nearestEarlyStopLocation.distance(from: currentStopLocation)
//            let minutesToAccountForDistance = Int(round(stopDistance / averageBusSpeed))
//
//            schedulePredictionMinutes.forEach { stopMinutesTuple in
//                if stopMinutesTuple.stopTag == firstStopTag
//                {
//                    let predictionMinutes = stopMinutesTuple.minutes-minutesToAccountForDistance
//                    if predictionMinutes < 0 { return }
//
//                    for extactPredictionTime in exactPredictions ?? []
//                    {
//                        guard let exactPredictionMinutes = Int(extactPredictionTime.time) else { continue }
//
//                        let minPredictionTimeToExclude = exactPredictionMinutes-scheduleToCurrentPredictionMarginOfError
//                        let maxPredictionTimeToExclude = exactPredictionMinutes+scheduleToCurrentPredictionMarginOfError
//
//                        if predictionMinutes >= minPredictionTimeToExclude && predictionMinutes <= maxPredictionTimeToExclude { return }
//                    }
//
//                    schedulePredictionTimes.append(PredictionTime(time: String(predictionMinutes), type: .schedule))
//                }
//            }
//        }
//
//        var fullPredictionTimes = (schedulePredictionTimes+(exactPredictions ?? []))
//        fullPredictionTimes.sort(by: { time1, time2 in
//            Int(time1.time) ?? 0 < Int(time2.time) ?? 0
//        })
//
//        for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//        {
//            NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":fullPredictionTimes, "directionStopID": directionStopID])
//
//            guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
//
//            fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
//        }
//    }
    
    static func fetchBARTPredictionTimes(route: Route, direction: Direction, stop: Stop) async -> PredictionTimeFetchResult
    {
        guard let bartPredictionContainer: BARTPredictionContainer = await fetchFromAPISource(api: BARTAPI.self, path: BARTAPI.predictionsPath, args: ["orig":stop.tag!]) else {
            return .error(reason: "Connection Error")
        }
        let predictionTimes = bartPredictionContainer.routes.reduce(Array<BARTPredictionTime>()) { partialResult, routePredictions in
            return partialResult + routePredictions.predictions.filter { prediction in
                return prediction.hexColor == route.color
            }
        }
        return .success(predictions: predictionTimes)
    }
    
//    static func fetchBARTPredictionTimes(route: Route, direction: Direction, stop: Stop)
//    {
//        getJSONFromBARTSource("/etd.aspx", "etd", ["key":RouteConstants.BARTAPIKey, "orig":stop.tag ?? ""]) { (json) in
//            let directionStopID = (stop.tag ?? "") + "-" + (direction.tag ?? "")
//
//            if let json = json
//            {
//                guard let routeHexColor = route.color else { return }
//
//                guard let directionTag = direction.tag else { return }
//                let directionTagSplit = directionTag.split(separator: "-")
//                if directionTagSplit.count < 2 { return }
//                let directionDestination = String(directionTagSplit[1])
//
//                let predictionsMain = (json["root"] as? Dictionary<String,Any> ?? [:])["station"] as? Array<Dictionary<String,Any>> ?? []
//                if predictionsMain.count < 1 { return }
//
//                var predictionTimes = Array<PredictionTime>()
//                if let etdArray = predictionsMain[0]["etd"] as? Array<Dictionary<String,Any>>
//                {
//                    for estimateTmp in etdArray
//                    {
//                        let destination = estimateTmp["abbreviation"] as? String
//                        let estimateArray = estimateTmp["estimate"] as? Array<Dictionary<String,String>> ?? []
//                        for estimate in estimateArray
//                        {
//                            guard var hexColor = estimate["hexcolor"] else { continue }
//                            let hexColorSplit = hexColor.split(separator: "#")
//                            if hexColorSplit.count < 1 { return }
//                            hexColor = String(hexColorSplit[0])
//
//                            if directionDestination == destination && routeHexColor.lowercased() == hexColor.lowercased()
//                            {
//                                predictionTimes.append(PredictionTime(time: estimate["minutes"] ?? "nil", type: .exact))
//                            }
//                        }
//                    }
//                }
//
//                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//                {
//                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["predictions":predictionTimes,"vehicleIDs":[], "directionStopID": directionStopID])
//
//                    guard let uuidIndex = fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID) else { continue }
//
//                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: uuidIndex)
//                }
//            }
//            else
//            {
//                for returnUUID in fetchPredictionTimesReturnUUIDS[directionStopID] ?? []
//                {
//                    NotificationCenter.default.post(name: NSNotification.Name("FoundPredictions:" + returnUUID), object: self, userInfo: ["error":"Connection Error", "directionStopID": directionStopID])
//
//                    fetchPredictionTimesReturnUUIDS[directionStopID]!.remove(at: fetchPredictionTimesReturnUUIDS[directionStopID]!.firstIndex(of: returnUUID)!)
//                }
//            }
//        }
//    }
    
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
    
    static func fetchVehicleLocations(vehicleIDs: [String], direction: Direction?) async -> VehicleLocationFetchResult
    {
        guard let route = direction?.route else { return .error(reason: "Invalid Route") }
        
        print("↓ - Fetching " + (direction?.tag ?? "") + " Locations")
        
        switch route.agency?.name
        {
        case UmoIQAPI.SFMTAAgencyTag:
            return await fetchUmoIQVehicleLocations(vehicleIDs: vehicleIDs, route: route)
        case BARTAPI.BARTAgencyTag:
            return .error(reason: "No Locations")
        default:
            return .error(reason: "Invalid Agency")
        }
        
//        DispatchQueue.global(qos: .background).async {
//            if let direction = direction, let route = direction.route, vehicleIDs.count > 0
//            {
//                getJSONFromNextBusSource("vehicleLocations", ["a":RouteConstants.NextBusAgencyTag,"r":route.tag!,"t":lastVehicleTime ?? "0"]) { (json) in
//                    guard let json = json else { return }
//
//                    let vehicles = json["vehicle"] as? Array<Dictionary<String,String>> ?? []
//
//                    var vehiclesInDirection = Array<(id: String, location: CLLocation, heading: Int)>()
//
//                    for vehicle in vehicles
//                    {
//                        if vehicleIDs.contains(vehicle["id"]!)
//                        {
//                            let id = vehicle["id"]!
//                            let lat = Double(vehicle["lat"]!) ?? 0
//                            let lon = Double(vehicle["lon"]!) ?? 0
//                            let location = CLLocation(latitude: lat, longitude: lon)
//                            let heading = Int(vehicle["heading"]!) ?? 0
//
//                            vehiclesInDirection.append((id: id, location: location, heading: heading))
//                        }
//                    }
//
//                    NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":vehiclesInDirection, "direction": direction.tag ?? ""])
//                }
//            }
//            else
//            {
//                NotificationCenter.default.post(name: NSNotification.Name("FoundVehicleLocations:" + returnUUID), object: nil, userInfo: ["vehicleLocations":[], "direction": direction?.tag ?? ""])
//            }
//        }
    }
    
    static func fetchUmoIQVehicleLocations(vehicleIDs: [String], route: Route) async -> VehicleLocationFetchResult
    {
        guard let routeVehicleLocations: Array<UmoIQRouteVehicleLocation> = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeVehiclesPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag, "route":route.tag!]) else {
            return .error(reason: "Connection Error")
        }
        return .success(vehicleLocations: routeVehicleLocations)
    }
    
    static func formatPredictions(predictions: Array<PredictionTime>, predictionsToShow: Int = 5) -> NSAttributedString
    {
        var predictionsString = ""
        var predictionOn = 0
        
        var predictions = predictions
        if predictions.count > predictionsToShow && predictions.count > 0 && predictionsToShow > 0
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
        
        Task
        {
            await RouteDataManager.updateAllData()
            task.setTaskCompleted(success: true)
        }
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

extension URLSession
{
    static var noCacheSession: URLSession = {
        let noCacheConfig = URLSessionConfiguration.default
        noCacheConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        noCacheConfig.urlCache = nil
        return URLSession(configuration: noCacheConfig)
    }()
}
