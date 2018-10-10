//
//  NotificationManager.swift
//  MuniTracker
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UserNotifications

class NotificationManager
{
    static func addNotification(stopNotification: StopNotification)
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
    }
}
