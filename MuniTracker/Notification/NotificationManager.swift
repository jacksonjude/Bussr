//
//  NotificationManager.swift
//  MuniTracker
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UserNotifications

extension StopNotification
{
    public override func prepareForDeletion() {
        NotificationCenter.default.post(name: NSNotification.Name("DeletedStopNotification"), object: nil, userInfo: ["uuid":self.notificationUUID!])
        
        super.prepareForDeletion()
    }
    
    public override func didSave() {
        super.didSave()
        
        if !isDeleted
        {
            NotificationCenter.default.post(name: NSNotification.Name("UpdatedStopNotification"), object: self)
        }
    }
}

class NotificationManager
{
    /*static func addNotification(stopNotification: StopNotification)
    {
        let todayDate = Date()
        let calendar = Calendar(identifier: .gregorian)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayDate))!
        
        let busStopNotificationContent = UNMutableNotificationContent()
        busStopNotificationContent.title = "Bus Times"
        
        let stop = RouteDataManager.fetchStop(stopTag: stopNotification.stopTag!)
        let direction = RouteDataManager.fetchDirection(directionTag: stopNotification.directionTag!)
        let routeTag = direction?.route?.routeTag ?? ""
        let directionName = direction?.directionName ?? ""
        let stopTitle = stop?.stopShortTitle ?? ""
        busStopNotificationContent.body = routeTag + " - " + directionName + " - " + stopTitle
        
        let notificationHour = stopNotification.hour
        let notificationMinute = stopNotification.minute
        
        let notificationDaysOfWeekJSONObject = try? JSONSerialization.jsonObject(with: stopNotification.daysOfWeek!, options: .allowFragments)
        
        if let notificationDaysOfWeek = notificationDaysOfWeekJSONObject as? [Bool]
        {
            let dayOfWeekOn = 0
            while dayOfWeekOn < notificationDaysOfWeek.count
            {
                if notificationDaysOfWeek[dayOfWeekOn]
                {
                    var triggerDateComponents = calendar.dateComponents([.year, .month, .day], from: startOfWeek.addingTimeInterval(TimeInterval(dayOfWeekOn*60*60*24)))
                    
                    triggerDateComponents.hour = Int(notificationHour)
                    triggerDateComponents.minute = Int(notificationMinute)
                    
                    let stopNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
                    
                    let stopNotificationRequest = UNNotificationRequest(identifier: stopNotification.notificationUUID!, content: busStopNotificationContent, trigger: stopNotificationTrigger)
                    
                    UNUserNotificationCenter.current().add(stopNotificationRequest) { (error) in
                        print(error.debugDescription)
                    }
                }
            }
        }
    }
    
    static func refreshNotifications()
    {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if let stopNotifications = RouteDataManager.fetchLocalObjects(type: "StopNotification", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [StopNotification]
        {
            for stopNotification in stopNotifications
            {
                addNotification(stopNotification: stopNotification)
            }
        }
    }*/
    
    static let notificationDatabaseSource = "http://munitracker.herokuapp.com"
    
    static func addObservationNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidUpdate(_:)), name: NSNotification.Name("UpdatedStopNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidDelete(_:)), name: NSNotification.Name("DeletedStopNotification"), object: nil)
    }
    
    @objc static func stopNotificationDidUpdate(_ notification: Notification)
    {
        let stopNotification = notification.object as! StopNotification
        updateNotification(stopNotification: stopNotification)
    }
    
    @objc static func stopNotificationDidDelete(_ notification: Notification)
    {
        let stopNotificationUUID = notification.userInfo!["uuid"] as! String
        deleteNotification(stopNotificationUUID: stopNotificationUUID)
    }
    
    static func updateNotification(stopNotification: StopNotification)
    {
        DispatchQueue.global(qos: .background).async {
            deleteNotification(stopNotificationUUID: stopNotification.notificationUUID!) {
                guard let deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String else { return }
                guard let routeTag = RouteDataManager.fetchDirection(directionTag: stopNotification.directionTag!)?.route?.routeTag else { return }
                guard let stopTitle = RouteDataManager.fetchStop(stopTag: stopNotification.stopTag!)?.stopTitle?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
                var queryString = "devicetoken=" + deviceToken + "&hour=" + String(stopNotification.hour) + "&minute=" + String(stopNotification.minute)
                queryString += "&daysofweek=" + String(data: stopNotification.daysOfWeek!, encoding: String.Encoding.utf8)!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                queryString += "&routetag=" + routeTag + "&stoptag=" + stopNotification.stopTag! + "&stoptitle=" + stopTitle + "&uuid=" + stopNotification.notificationUUID!
                let addTask = (URLSession.shared.dataTask(with: URL(string: self.notificationDatabaseSource + "/addnotification/?" + queryString)!) { data, response, error in
                    
                })
                addTask.resume()
            }
        }
        
    }
    
    static func deleteNotification(stopNotificationUUID: String, callback: (() -> Void)? = nil)
    {
        DispatchQueue.global(qos: .background).async {
            let deleteTask = (URLSession.shared.dataTask(with: URL(string: notificationDatabaseSource + "/deletenotification/?uuid=" + stopNotificationUUID)!) { data, response, error in
                callback?()
            })
            
            deleteTask.resume()
        }
    }
}
