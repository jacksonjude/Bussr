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
                
                let notificationDateString = String(stopNotification.hour) + ":" + ((stopNotification.minute < 10) ? "0" : "") +  String(stopNotification.minute)
                let UTCNotificationDateString = convertToUTCFromLocalDate(dateStr: notificationDateString)
                let notificationHour = Int(UTCNotificationDateString.split(separator: ":")[0]) ?? 0
                let notificationMinute = Int(UTCNotificationDateString.split(separator: ":")[1]) ?? 0
                
                var queryString = "devicetoken=" + deviceToken + "&hour=" + String(notificationHour) + "&minute=" + String(notificationMinute)
                queryString += "&daysofweek=" + String(data: stopNotification.daysOfWeek!, encoding: String.Encoding.utf8)!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                queryString += "&routetag=" + routeTag + "&stoptag=" + stopNotification.stopTag! + "&stoptitle=" + stopTitle + "&uuid=" + stopNotification.notificationUUID!
                let addTask = (URLSession.shared.dataTask(with: URL(string: self.notificationDatabaseSource + "/addnotification/?" + queryString)!) { data, response, error in
                    
                })
                addTask.resume()
            }
        }
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
        //print(formatter.string(from: utcCurrentDate))
        return formatter.string(from: utcCurrentDate)
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
