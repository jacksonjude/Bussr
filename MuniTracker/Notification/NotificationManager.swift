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
    static let notificationDatabaseSource = "http://munitracker.herokuapp.com"
    
    static func addObservationNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidUpdate(_:)), name: NSNotification.Name("UpdatedStopNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopNotificationDidDelete(_:)), name: NSNotification.Name("DeletedStopNotification"), object: nil)
    }
    
    @objc static func stopNotificationDidUpdate(_ notification: Notification)
    {
        let stopNotification = notification.object as! StopNotification
        notificationChanges[stopNotification.notificationUUID!] = 0
        
        syncNotificationChangesToServer()
    }
    
    @objc static func stopNotificationDidDelete(_ notification: Notification)
    {
        let stopNotificationUUID = notification.userInfo!["uuid"] as! String
        notificationChanges[stopNotificationUUID] = 1
        
        syncNotificationChangesToServer()
    }
    
    static func updateNotification(stopNotification: StopNotification, callback: ((_ error: Error?) -> Void)? = nil)
    {
        guard let deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String else { return }
        guard let routeTag = RouteDataManager.fetchDirection(directionTag: stopNotification.directionTag!)?.route?.routeTag else { return }
        guard let stopTitle = RouteDataManager.fetchStop(stopTag: stopNotification.stopTag!)?.stopTitle?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
        
        let notificationDateString = String(stopNotification.hour) + ":" + ((stopNotification.minute < 10) ? "0" : "") +  String(stopNotification.minute)
        let UTCNotificationDateString = convertToUTCFromLocalDate(dateStr: notificationDateString)
        let notificationHour = Int(UTCNotificationDateString.split(separator: ":")[0]) ?? 0
        let notificationMinute = Int(UTCNotificationDateString.split(separator: ":")[1]) ?? 0
        
        var queryString = "devicetoken=" + deviceToken + "&hour=" + String(notificationHour) + "&minute=" + String(notificationMinute)
        queryString += "&daysofweek=" + String(data: stopNotification.daysOfWeek!, encoding: String.Encoding.utf8)!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        queryString += "&routetag=" + routeTag + "&stoptag=" + stopNotification.stopTag! + "&stoptitle=" + stopTitle + "&uuid=" + stopNotification.notificationUUID!
        
        deleteNotification(stopNotificationUUID: stopNotification.notificationUUID!, callback: { (error) in
            
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
    
    static var notificationChanges = Dictionary<String,Int>()
    
    static func syncNotificationChangesToServer()
    {
        print("↑ Syncing Notifications to Cloud")
        CoreDataStack.persistentContainer.performBackgroundTask { (backgroundMOC) in
            for change in notificationChanges
            {
                switch change.value
                {
                case 0:
                    if let stopNotification = RouteDataManager.fetchLocalObjects(type: "StopNotification", predicate: NSPredicate(format: "notificationUUID == %@", change.key), moc: backgroundMOC) as? [StopNotification], stopNotification.count > 0
                    {
                        updateNotification(stopNotification: stopNotification[0], callback: { (error) in
                            if error == nil
                            {
                                notificationChanges.removeValue(forKey: change.key)
                            }
                        })
                    }
                case 1:
                    deleteNotification(stopNotificationUUID: change.key, callback: { (error) in
                        if error == nil
                        {
                            notificationChanges.removeValue(forKey: change.key)
                        }
                    })
                default:
                    break
                }
            }
        }
    }
}
