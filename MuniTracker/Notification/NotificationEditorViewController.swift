//
//  NotificationEditorViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/9/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit

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
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        //let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            notificationEditorNavigationBar.barTintColor = nil
            notificationEditorNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
            self.view.backgroundColor = offWhite
        case .dark:
            notificationEditorNavigationBar.barTintColor = black
            notificationEditorNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
            self.view.backgroundColor = black
        }
        
    }
    
    func loadNotificationData()
    {
        NotificationEditorState.notificationHour = stopNotification?.hour
        NotificationEditorState.notificationMinute = stopNotification?.minute
        
        if let repeatArrayData = stopNotification?.daysOfWeek
        {
            NotificationEditorState.notificationRepeatArray = try? JSONSerialization.jsonObject(with: repeatArrayData, options: JSONSerialization.ReadingOptions.allowFragments) as! Array<Bool>
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ReloadNotificationEditorViews"), object: nil)
    }
    
    func saveNotificationData()
    {
        stopNotification?.hour = NotificationEditorState.notificationHour ?? 0
        stopNotification?.minute = NotificationEditorState.notificationMinute ?? 0
        stopNotification?.daysOfWeek = try? JSONSerialization.data(withJSONObject: NotificationEditorState.notificationRepeatArray ?? [], options: JSONSerialization.WritingOptions.sortedKeys)
        
        CoreDataStack.saveContext()
    }
    
    @objc func exitNewNotificationEditor()
    {
        self.performSegue(withIdentifier: "unwindFromNewNotificationEditor", sender: self)
    }
    
    @IBAction func exitNotificationEditor()
    {
        self.performSegue(withIdentifier: "unwindFromNotificationEditor", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindFromNotificationEditor"
        {
            saveNotificationData()
        }
    }
}
