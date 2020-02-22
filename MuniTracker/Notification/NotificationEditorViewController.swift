//
//  NotificationEditorViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/9/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CloudCore

class NotificationEditorViewController: UIViewController
{
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var notificationEditorNavigationBar: UINavigationBar!
    var stopNotification: StopNotification?
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
        NotificationEditorState.notificationHour = stopNotification?.hour
        NotificationEditorState.notificationMinute = stopNotification?.minute
        
        if let repeatArrayData = stopNotification?.daysOfWeek
        {
            NotificationEditorState.notificationRepeatArray = try? JSONSerialization.jsonObject(with: repeatArrayData, options: JSONSerialization.ReadingOptions.allowFragments) as? Array<Bool>
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ReloadNotificationEditorViews"), object: nil)
    }
    
    var mocSaveGroup = DispatchGroup()
    
    func saveNotificationData()
    {
        CoreDataStack.persistentContainer.performBackgroundTask { moc in
            moc.name = CloudCore.config.pushContextName
            
            guard let stopNotificationID = self.stopNotification?.objectID else { return }
            let stopNotification = try? moc.existingObject(with: stopNotificationID) as? StopNotification
            stopNotification?.hour = NotificationEditorState.notificationHour ?? 0
            stopNotification?.minute = NotificationEditorState.notificationMinute ?? 0
            stopNotification?.daysOfWeek = try? JSONSerialization.data(withJSONObject: NotificationEditorState.notificationRepeatArray ?? [], options: JSONSerialization.WritingOptions.sortedKeys)
            stopNotification?.deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String
            
            try? moc.save()
        }
    }
    
    @objc func savedBackgroundMOC()
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        mocSaveGroup.leave()
    }
    
    @objc func exitNewNotificationEditor()
    {
        self.performSegue(withIdentifier: "unwindFromNewNotificationEditor", sender: self)
    }
    
    @IBAction func exitNotificationEditor()
    {
        mocSaveGroup.enter()
        NotificationCenter.default.addObserver(self, selector: #selector(savedBackgroundMOC), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        saveNotificationData()
        mocSaveGroup.wait()
        self.performSegue(withIdentifier: "unwindFromNotificationEditor", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindFromNotificationEditor" || segue.identifier == "unwindFromNewNotificationEditor"
        {
            //saveNotificationData()
        }
    }
}
