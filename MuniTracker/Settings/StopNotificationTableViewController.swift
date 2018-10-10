//
//  StopNotificationTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class StopNotificationTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var notificationObjects: Array<StopNotification>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.registerForPushNotifications()
        fetchNotificationObjects()
    }
    
    func fetchNotificationObjects()
    {
        notificationObjects = Array<StopNotification>()
        if let stopNotificationObjects = RouteDataManager.fetchLocalObjects(type: "StopNotification", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [StopNotification]
        {
            notificationObjects = stopNotificationObjects
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "StopNotificationCell")!
    }
    
    
}
