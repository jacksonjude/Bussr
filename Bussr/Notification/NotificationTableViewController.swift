//
//  StopNotificationTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData
import CloudCore

class NotificationTableViewController: UITableViewController, NSFetchedResultsControllerDelegate
{
    let hourOffset = Calendar(identifier: .gregorian).component(.hour, from: Date(timeIntervalSince1970: 0.0))-24
    var isEditingTableView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        appDelegate.registerForPushNotifications()
        
        try? fetchedResultsController.performFetch()
        
        self.clearsSelectionOnViewWillAppear = true
    }
    
    //MARK: - Fetched Results Controller
    
    var fetchedResultsController: NSFetchedResultsController<StopNotification> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<StopNotification> = StopNotification.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 50
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "routeTag", ascending: false)]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController<StopNotification>(fetchRequest: fetchRequest, managedObjectContext: CoreDataStack.persistentContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
             // Replace this implementation with code to handle the error appropriately.
             // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             let nserror = error as NSError
             fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<StopNotification>? = nil
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
            case .insert:
                tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            case .delete:
                tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            default:
                return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .fade)
            case .update:
                configureCell(cell: tableView.cellForRow(at: indexPath!)!, notification: anObject as! StopNotification)
            case .move:
                configureCell(cell: tableView.cellForRow(at: indexPath!)!, notification: anObject as! StopNotification)
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
            default:
                return
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    //MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StopNotificationCell", for: indexPath)
        let notification = fetchedResultsController.object(at: indexPath)
        configureCell(cell: cell, notification: notification)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func configureCell(cell: UITableViewCell, notification: StopNotification)
    {
        if let direction = RouteDataManager.fetchDirection(directionTag: notification.directionTag ?? "")
        {
            (cell.viewWithTag(600) as! UILabel).text = direction.route?.tag
            (cell.viewWithTag(601) as! UILabel).text = direction.name
            
            if let route = direction.route
            {
                let routeColor = UIColor(hexString: route.color ?? "000000")
                let routeOppositeColor = UIColor(hexString: route.oppositeColor ?? "000000")
                
                cell.backgroundColor = routeColor
                
                (cell.viewWithTag(600) as! UILabel).textColor = routeOppositeColor
                (cell.viewWithTag(601) as! UILabel).textColor = routeOppositeColor
                (cell.viewWithTag(602) as! UILabel).textColor = routeOppositeColor
                (cell.viewWithTag(603) as! UILabel).textColor = routeOppositeColor
            }
        }
        else
        {
            cell.backgroundColor = UIColor.gray
            cell.isUserInteractionEnabled = false
        }
        
        if let stop = RouteDataManager.fetchStop(stopTag: notification.stopTag ?? "")
        {
            (cell.viewWithTag(602) as! UILabel).text = stop.title
        }
        
        var notificationHour = Int(notification.hour) + hourOffset
        if notificationHour < 0
        {
            notificationHour += 24
        }
        if notificationHour > 24
        {
            notificationHour -= 24
        }
        
        var notification12Hour = notificationHour
        if notification12Hour > 12
        {
            notification12Hour -= 12
        }
        if notification12Hour == 0
        {
            notification12Hour = 12
        }
        
        let notificationHourFormatted = String(notification12Hour)
        let notificationStopFormatted = ((notification.minute) < 10) ? "0" + String(notification.minute) : String(notification.minute)
        
        (cell.viewWithTag(603) as! UILabel).text = notificationHourFormatted + ":" + notificationStopFormatted + " " + ((notificationHour >= 12) ? "PM" : "AM")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? NotificationEditorViewController, let selectedRow = tableView.indexPathForSelectedRow
        {
            let notification = fetchedResultsController.object(at: selectedRow)
            destination.stopNotificationID = notification.objectID
        }
    }
    
    @IBAction func unwindFromNotificationEditorTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @objc @IBAction func editButtonPressed(_ sender: Any) {
        isEditingTableView = !isEditingTableView
        
        tableView.setEditing(isEditingTableView, animated: true)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: isEditingTableView ? UIBarButtonItem.SystemItem.save : UIBarButtonItem.SystemItem.edit, target: self, action: #selector(editButtonPressed(_:)))
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let notification = fetchedResultsController.object(at: indexPath)
        let notificationID = notification.objectID
        
        CoreDataStack.persistentContainer.performBackgroundTask { moc in
            moc.name = CloudCore.config.pushContextName
            
            guard let stopNotification = moc.object(with: notificationID) as? StopNotification else { return }
            
            moc.delete(stopNotification)
            
            try? moc.save()
        }
    }
}
