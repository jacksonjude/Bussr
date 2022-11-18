//
//  NotificationManager.swift
//  Bussr
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UserNotifications
import CoreData

enum NotificationChangeType: Int
{
    case updated = 0
    case deleted = 1
}

//extension StopNotification
//{
//    public override func prepareForDeletion() {
//        if let notificationUUID = self.uuid
//        {
//            NotificationCenter.default.post(name: NSNotification.Name("DeletedStopNotification"), object: nil, userInfo: ["uuid":notificationUUID])
//        }
//
//        super.prepareForDeletion()
//    }
//
//    public override func didSave() {
//        super.didSave()
//
//        if !isDeleted
//        {
//            NotificationCenter.default.post(name: NSNotification.Name("UpdatedStopNotification"), object: self)
//        }
//    }
//}

class NotificationManager
{
    static let notificationDatabaseSource = "http://munitracker.herokuapp.com"
    
    static func addObservationNotifications()
    {
        self.notificationChanges = Dictionary<String,NotificationChangeType>()
        
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidUpdate(_:)), name: NSNotification.Name("UpdatedStopNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidDelete(_:)), name: NSNotification.Name("DeletedStopNotification"), object: nil)
    }
    
    @objc static func stopNotificationDidUpdate(_ notification: Notification)
    {
        let stopNotification = notification.object as! StopNotification
        notificationChanges?[stopNotification.uuid!] = NotificationChangeType.updated
        
        OperationQueue.main.addOperation { //Strange crash when iterating thru notification changes on sync
            syncNotificationChangesToServer()
        }
    }
    
    @objc static func stopNotificationDidDelete(_ notification: Notification)
    {
        let stopNotificationUUID = notification.userInfo!["uuid"] as! String
        notificationChanges?[stopNotificationUUID] = NotificationChangeType.deleted
        
        syncNotificationChangesToServer()
    }
    
    static func updateNotification(stopNotification: StopNotification, moc: NSManagedObjectContext, callback: ((_ error: Error?) -> Void)? = nil)
    {
        guard let deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String else { return }
        guard let routeTag = RouteDataManager.fetchDirection(directionTag: stopNotification.directionTag!, moc: moc)?.route?.tag else { return }
        guard let stopTitle = RouteDataManager.fetchStop(stopTag: stopNotification.stopTag!, moc: moc)?.title?.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return }
        
        let notificationDateString = String(stopNotification.hour) + ":" + ((stopNotification.minute < 10) ? "0" : "") +  String(stopNotification.minute)
        let UTCNotificationDateString = convertToUTCFromLocalDate(dateStr: notificationDateString)
        let notificationHour = Int(UTCNotificationDateString.split(separator: ":")[0]) ?? 0
        let notificationMinute = Int(UTCNotificationDateString.split(separator: ":")[1]) ?? 0
        
        var queryString = "devicetoken=" + deviceToken + "&hour=" + String(notificationHour) + "&minute=" + String(notificationMinute)
        queryString += "&daysofweek=" + String(data: stopNotification.daysOfWeek!, encoding: String.Encoding.utf8)!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        queryString += "&routetag=" + routeTag + "&stoptag=" + stopNotification.stopTag! + "&stoptitle=" + stopTitle + "&uuid=" + stopNotification.uuid!
        
        deleteNotification(stopNotificationUUID: stopNotification.uuid!, callback: { (error) in
            
            if error != nil
            {
                return
            }
            
            let addTask = (URLSession.shared.dataTask(with: URL(string: self.notificationDatabaseSource + "/addnotification/?" + queryString)!) { data, response, error in
                callback?(error)
            })
            addTask.resume()
        })
    }
    
    static func convertToUTCFromLocalDate(dateStr : String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let utc = NSTimeZone(abbreviation: "UTC")
        formatter.timeZone = utc! as TimeZone
        formatter.dateFormat = "HH:mm"
        let localDate: Date? = formatter.date(from: dateStr)
        let timeZoneOffset: TimeInterval = TimeInterval(NSTimeZone.default.secondsFromGMT())
        let utcTimeInterval: TimeInterval? = (localDate?.timeIntervalSinceReferenceDate)! - timeZoneOffset
        let utcCurrentDate = Date(timeIntervalSinceReferenceDate: utcTimeInterval!)
        return formatter.string(from: utcCurrentDate)
    }
    
    static func deleteNotification(stopNotificationUUID: String, callback: ((_ error: Error?) -> Void)? = nil)
    {
        let deleteTask = (URLSession.shared.dataTask(with: URL(string: notificationDatabaseSource + "/deletenotification/?uuid=" + stopNotificationUUID)!) { data, response, error in
            callback?(error)
        })
        
        deleteTask.resume()
    }
    
    static var notificationChanges: Dictionary<String,NotificationChangeType>?
    
    static func syncNotificationChangesToServer()
    {
        print("↑ - Syncing Notifications to Cloud")
        CoreDataStack.persistentContainer.performBackgroundTask { (backgroundMOC) in
            guard let notificationChanges = self.notificationChanges else { return }
            for change in notificationChanges
            {
                switch change.value
                {
                case NotificationChangeType.updated:
                    if let stopNotification = CoreDataStack.fetchLocalObjects(type: "StopNotification", predicate: NSPredicate(format: "uuid == %@", change.key), moc: backgroundMOC) as? [StopNotification], stopNotification.count > 0
                    {
                        updateNotification(stopNotification: stopNotification[0], moc: backgroundMOC, callback: { (error) in
                            if error == nil
                            {
                                self.notificationChanges?.removeValue(forKey: change.key)
                            }
                        })
                    }
                case NotificationChangeType.deleted:
                    deleteNotification(stopNotificationUUID: change.key, callback: { (error) in
                        if error == nil
                        {
                            self.notificationChanges?.removeValue(forKey: change.key)
                        }
                    })
                }
            }
        }
    }
}
