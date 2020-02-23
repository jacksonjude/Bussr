//
//  NotificationEditorViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/9/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CloudCore
import CoreData

class NotificationEditorViewController: UIViewController
{
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var notificationEditorNavigationBar: UINavigationBar!
    var stopNotificationID: NSManagedObjectID?
    var newNotification = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if newNotification
        {
            backButton.action = #selector(exitNewNotificationEditor)
        }
        else
        {
            backButton.action = #selector(exitNotificationEditor)
        }
        
        setupThemeElements()
        
        loadNotificationData()
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            break
        case .dark:
            break
        }
    }
    
    func loadNotificationData()
    {
        guard let stopNotificationID = stopNotificationID else { return }
        let notification = CoreDataStack.persistentContainer.viewContext.object(with: stopNotificationID) as! StopNotification
        
        NotificationEditorState.notificationHour = notification.hour
        NotificationEditorState.notificationMinute = notification.minute
        
        if let repeatArrayData = notification.daysOfWeek
        {
            NotificationEditorState.notificationRepeatArray = try? JSONSerialization.jsonObject(with: repeatArrayData, options: JSONSerialization.ReadingOptions.allowFragments) as? Array<Bool>
        }
        
        NotificationEditorState.newNotification = self.newNotification
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ReloadNotificationEditorViews"), object: nil)
    }
        
    @objc func saveNotificationData()
    {
        guard let stopNotificationID = stopNotificationID else { return }
        
        CoreDataStack.persistentContainer.performBackgroundTask { moc in
            moc.name = CloudCore.config.pushContextName
            
            let stopNotification = try? moc.existingObject(with: stopNotificationID) as? StopNotification
            stopNotification?.hour = NotificationEditorState.notificationHour ?? 0
            stopNotification?.minute = NotificationEditorState.notificationMinute ?? 0
            stopNotification?.daysOfWeek = try? JSONSerialization.data(withJSONObject: NotificationEditorState.notificationRepeatArray ?? [], options: JSONSerialization.WritingOptions.sortedKeys)
            stopNotification?.deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String
            
            try? moc.save()
        }
    }
    
    @objc func exitNewNotificationEditor()
    {
        saveNotificationData()
        self.performSegue(withIdentifier: "unwindFromNewNotificationEditor", sender: self)
    }
    
    @IBAction func exitNotificationEditor()
    {
        saveNotificationData()
        self.performSegue(withIdentifier: "unwindFromNotificationEditor", sender: self)
    }
}
