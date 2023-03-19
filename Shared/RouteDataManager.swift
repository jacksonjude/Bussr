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
    static let herokuHashSource = "http://munitracker.herokuapp.com"
}

protocol AgencyFormat
{
    associatedtype U: APIFormat
    static var agencyTag: String { get }
    static var api: U.Type { get }
    static var maxFullDetailWidth: Double { get }
    static var listHashPath: String? { get }
    static var configHashPath: String? { get }
}

struct UmoIQAgency: AgencyFormat
{
    static let agencyTag = "sfmta-cis"
    static let api = UmoIQAPI.self
    static let maxFullDetailWidth = 4000.0
    static let listHashPath: String? = nil
    static let configHashPath: String? = nil
}

struct BARTAgency: AgencyFormat
{
    static let agencyTag = "BART"
    static let api = BARTAPI.self
    static let maxFullDetailWidth = 22000.0
    static let listHashPath: String? = "/rlbarthash"
    static let configHashPath: String? = "/rcbarthash"
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
    static let apiKey = "efb2289a-c289-40f2-85e7-92cde339ee34"
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
        
//        let BARTRouteListHash = fetchRouteListHash(agencyTag: BARTAPI.BARTAgencyTag)
//        let BARTRouteConfigHashes = fetchRouteConfigHashes(agencyTag: BARTAPI.BARTAgencyTag)
//
//        let BARTRouteDictionary = await fetchBARTRoutes()
//        let BARTSortedRouteKeys = Array<String>(BARTRouteDictionary.keys).sorted { (routeTag1, routeTag2) -> Bool in
//            return routeTag1.localizedStandardCompare(routeTag2) == .orderedAscending
//        }
//        let BARTStopConfig = await fetchBARTStops()
//        print("Received BART Routes")
        
        self.totalRoutes = UmoIQRouteDictionary.count// + BARTRouteDictionary.count
        
        await self.loadRouteInfo(routeDictionary: UmoIQRouteDictionary, sortedRouteKeys: UmoIQSortedRouteKeys, agencyTag: UmoIQAPI.SFMTAAgencyTag, listHash: UmoIQAgencyRevision, configHashes: UmoIQRouteRevisions, fetchRouteConfig: fetchUmoIQRouteInfo) { routeConfig, _, backgroundMOC, configHashes, agencyTag -> (route: Route, justCreated: Bool)? in
            let routeFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeConfig.tag), moc: backgroundMOC)
            let routeObject = routeFetchCallback.object as! Route

            routeObject.tag = routeConfig.tag
            routeObject.title = routeConfig.title

            if let updatedHash = configHashes[routeConfig.tag]
            {
                routeObject.serverHash = updatedHash
            }

            print(agencyTag + " - " + routeConfig.tag)

            routeObject.color = routeConfig.color
            routeObject.oppositeColor = routeConfig.oppositeColor

            return (routeObject, routeFetchCallback.justCreated)
        }
                
//        await self.loadRouteInfo(routeDictionary: BARTRouteDictionary, sortedRouteKeys: BARTSortedRouteKeys, agencyTag: BARTAPI.BARTAgencyTag, listHash: BARTRouteListHash, configHashes: BARTRouteConfigHashes, fetchRouteConfig: fetchBARTRouteInfo) { (routeConfig: inout RouteConfiguration, routeConfigurationDictionary, backgroundMOC, configHashes, agencyTag) -> (route: Route, justCreated: Bool)? in
//            let routeNumber = routeConfig.tag
//            var routeAbbr = BARTRouteDictionary[routeNumber] ?? (routeConfig as! BARTRouteConfiguration).abbr
//
//            let routeStartEnd = routeAbbr.split(separator: "-")
//            let reverseRouteAbbr = String(routeStartEnd[1] + "-" + routeStartEnd[0])
//
//            var tempRouteAbbr = routeAbbr
//            var reverseRouteAbbrUsed = false
//            var reverseRouteNumber: String?
//            if BARTRouteDictionary.values.contains(reverseRouteAbbr)
//            {
//                reverseRouteNumber = BARTRouteDictionary.keys[BARTRouteDictionary.values.firstIndex(of: reverseRouteAbbr)!]
//                reverseRouteAbbrUsed = routeNumber > reverseRouteNumber!
//                tempRouteAbbr = routeNumber < reverseRouteNumber! ? routeAbbr : reverseRouteAbbr
//            }
//
//            if reverseRouteAbbrUsed
//            {
//                routesSaved += 1
//                checkForCompletedRoutes()
//
//                return nil
//            }
//
//            let routeFetchCallback = CoreDataStack.fetchOrCreateObject(type: "Route", predicate: NSPredicate(format: "tag == %@", BARTAPI.BARTAgencyTag + "-" + tempRouteAbbr), moc: backgroundMOC)
//            let routeObject = routeFetchCallback.object as! Route
//
//            if let updatedHash = configHashes[BARTAPI.BARTAgencyTag + "-" + routeNumber]
//            {
//                routeObject.serverHash = updatedHash
//            }
//
//            print(agencyTag + " - " + routeAbbr)
//
//            if BARTRouteDictionary.values.contains(reverseRouteAbbr)
//            {
//                let reverseRouteNumber = BARTRouteDictionary.keys[BARTRouteDictionary.values.firstIndex(of: reverseRouteAbbr)!]
//                if let reverseRouteConfig = routeConfigurationDictionary[reverseRouteNumber], let reverseRouteDirection = reverseRouteConfig.directions.first
//                {
//                    routeConfig.directions.append(reverseRouteDirection)
//                }
//
//                //Checking for ordering (lowest routeNumber)
//                routeAbbr = routeNumber < reverseRouteNumber ? routeAbbr : reverseRouteAbbr
//            }
//
//            routeObject.tag = BARTAPI.BARTAgencyTag + "-" + routeAbbr
//            routeObject.title = routeConfig.title
//
//            routeObject.color = routeConfig.color
//            routeObject.oppositeColor = routeConfig.oppositeColor
//
//            if let stopArray = BARTStopConfig
//            {
//                try? (routeConfig as! BARTRouteConfiguration).loadStops(from: stopArray)
//            }
//
//            return (routeObject, routeFetchCallback.justCreated)
//        }
    }
    
    static func loadRouteInfo(routeDictionary: Dictionary<String,String>, sortedRouteKeys: Array<String>, agencyTag: String, listHash: String, configHashes: Dictionary<String,String>, fetchRouteConfig: (_ routeTag: String) async -> RouteConfiguration?, setRouteFields: @escaping (_ routeConfig: inout RouteConfiguration, _ routeConfigurationDictionary: Dictionary<String,RouteConfiguration>, _ backgroundMOC: NSManagedObjectContext, _ configHashes: Dictionary<String,String>, _ agencyTag: String) -> (route: Route, justCreated: Bool)?) async
    {
        let backgroundMOC = CoreDataStack.persistentContainer.newBackgroundContext()
        
        var routeConfigurations = Dictionary<String,RouteConfiguration>()
        for routeTag in sortedRouteKeys
        {
            updateRouteFetchProgress(routeTagOn: "Fetching " + agencyTag + " " + routeTag)
            routesFetched += 1
            
            var route: Route?
            await backgroundMOC.perform {
                route = CoreDataStack.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeTag), moc: backgroundMOC) as? Route
            }
            if let route = route, route.serverHash != nil, route.serverHash == configHashes[routeTag] { continue }
            
            guard let routeConfig = await fetchRouteConfig(routeTag) else { continue }
            routeConfigurations[routeTag] = routeConfig
        }
        
        updateRouteFetchProgress(routeTagOn: "Saving " + agencyTag)
        
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
        guard let agency: UmoIQAgencyInstance = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.agencyPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag]) else { return "" }
        return String(agency.revision)
    }
    
    static func fetchUmoIQRouteInfo(routeTag: String) async -> UmoIQRouteConfiguration?
    {
        let routeConfiguration: UmoIQRouteConfiguration? = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeInfoPath, args: ["agency":UmoIQAPI.SFMTAAgencyTag, "route":routeTag])
        return routeConfiguration
    }
    
    static func fetchRouteListHash(agencyTag: String) -> String
    {
        var routeListHash = ""

        let backgroundGroup = DispatchGroup()
        backgroundGroup.enter()
        
        var listHashPath: String? = nil
        switch agencyTag
        {
        case UmoIQAgency.agencyTag:
            listHashPath = UmoIQAgency.listHashPath
        case BARTAgency.agencyTag:
            listHashPath = BARTAgency.listHashPath
        default:
            break
        }
        guard let listHashPath = listHashPath else { return routeListHash }
        
        let url = URL(string: RouteConstants.herokuHashSource + listHashPath + "?_=" + String(Date().timeIntervalSince1970))!
        
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
        
        var configHashPath: String? = nil
        switch agencyTag
        {
        case UmoIQAgency.agencyTag:
            configHashPath = UmoIQAgency.configHashPath
        case BARTAgency.agencyTag:
            configHashPath = BARTAgency.configHashPath
        default:
            break
        }
        guard let configHashPath = configHashPath else { return routeConfigHashes }
        
        let url = URL(string: RouteConstants.herokuHashSource + configHashPath + "?_=" + String(Date().timeIntervalSince1970))!
        
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
    
    static func fetchBARTPredictionTimes(route: Route, direction: Direction, stop: Stop) async -> PredictionTimeFetchResult
    {
        guard let bartPredictionContainer: BARTPredictionContainer = await fetchFromAPISource(api: BARTAPI.self, path: BARTAPI.predictionsPath, args: ["orig":stop.tag!]) else {
            return .error(reason: "Connection Error")
        }
        let routePredictions = bartPredictionContainer.stations.first?.routes
        let predictionTimes = routePredictions?.reduce(Array<BARTPredictionTime>()) { partialResult, routePredictions in
            if routePredictions.abbreviation != String(direction.tag!.split(separator: "-")[1]) { return partialResult }
            return partialResult + routePredictions.predictions.filter { prediction in
                return prediction.hexColor == ("#" + (route.color?.lowercased() ?? ""))
            }
        } ?? []
        return .success(predictions: predictionTimes)
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
    }
    
    static func fetchUmoIQVehicleLocations(vehicleIDs: [String], route: Route) async -> VehicleLocationFetchResult
    {
        guard let routeVehicleLocations: Array<UmoIQRouteVehicleLocation> = await fetchFromAPISource(api: UmoIQAPI.self, path: UmoIQAPI.routeVehiclesPath, args: ["agency":UmoIQAgency.agencyTag, "route":route.tag!]) else {
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
