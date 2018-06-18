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
    static let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
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
                fetchRoutes()
            default:
                break
            }
        }
        else
        {
            queueIsRunning = false
        }
    }
    
    
    static func fetchRoutes()
    {
        /*let XMLRouteParser = XMLParser(contentsOf: URL(string: xmlFeedSource + "?command=routeList&a=sf-muni")!)
        XMLRouteParser?.delegate = self
        XMLRouteParser?.parse()*/
        
        Alamofire.request(URL(string: xmlFeedSource + "?command=routeList&a=sf-muni")!).responseData { (response) in
            let xml = SWXMLHash.parse(response.result.value!)
            
            let xmlBody = xml.children[0]
            var routeDictionary = Dictionary<String,String>()
            
            for bodyChild in xmlBody.children
            {
                if bodyChild.element?.text != "\n"
                {
                    routeDictionary[(bodyChild.element?.allAttributes["tag"]?.text)!] = (bodyChild.element?.allAttributes["title"]?.text)!
                }
            }
                        
            NotificationCenter.default.post(name: NSNotification.Name("ParsedXML:" + self.fetchQueue.keys.first!), object: self, userInfo: ["xmlDictionary":routeDictionary])
        }
    }
    
    static func fetchLocalObjects(type: String, predicate: NSPredicate) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        let fetchResults: [AnyObject]?
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
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        /*var currentArray: Array<Any> = currentData
        
        let splitCurrentDataPath = currentDataPath.split(separator: "-")
        for indexString in splitCurrentDataPath
        {
            let indexInt = Int(String(indexString))
            
            currentArray = currentArray[indexInt!] as! Array<Any>
        }
        currentArray.append([elementName, attributeDict, Array<Any>()])
        
        if currentDataPath != ""
        {
            currentDataPath += "-"
        }
        currentDataPath += String(currentArray.count-1) + "-" + "2"*/
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        /*let splitCurrentDataPath = currentDataPath.split(separator: "-")
        
        var splitNumberOn = 0
        currentDataPath = ""
        for splitString in splitCurrentDataPath
        {
            if splitNumberOn != splitCurrentDataPath.count
            {
                currentDataPath += String(splitString)
            }
            splitNumberOn += 1
        }*/
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        
    }
}
