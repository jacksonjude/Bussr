//
//  StopNotificationTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/7/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet weak var stopNotificationTableView: UITableView!
    @IBOutlet weak var notificationNavigationItem: UINavigationItem!
    @IBOutlet weak var notificationNavigationBar: UINavigationBar!
    
    var notificationObjects: Array<StopNotification>?
    var isEditingTableView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupThemeElements()
        
        appDelegate.registerForPushNotifications()
        fetchNotificationObjects()
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
    
    func fetchNotificationObjects()
    {
        notificationObjects = Array<StopNotification>()
        if let stopNotificationObjects = RouteDataManager.fetchLocalObjects(type: "StopNotification", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [StopNotification]
        {
            notificationObjects = stopNotificationObjects
        }
        
        stopNotificationTableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notificationObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StopNotificationCell")!
        
        //cell.textLabel?.text = notificationObjects?[indexPath.row].
        configureCell(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func configureCell(cell: UITableViewCell, indexPath: IndexPath)
    {
        if let direction = RouteDataManager.fetchDirection(directionTag: notificationObjects?[indexPath.row].directionTag ?? "")
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
        
        if let stop = RouteDataManager.fetchStop(stopTag: notificationObjects?[indexPath.row].stopTag ?? "")
        {
            (cell.viewWithTag(602) as! UILabel).text = stop.title
        }
        
        let notificationHourFormatted =  String(((notificationObjects?[indexPath.row].hour ?? 0) > 12) ? (notificationObjects?[indexPath.row].hour ?? 0) - 12 : notificationObjects?[indexPath.row].hour ?? 0)
        let notificationStopFormatted = ((notificationObjects?[indexPath.row].minute ?? 0) < 10) ? "0" + String(notificationObjects?[indexPath.row].minute ?? 0) : String(notificationObjects?[indexPath.row].minute ?? 0)
        
        (cell.viewWithTag(603) as! UILabel).text = notificationHourFormatted + ":" + notificationStopFormatted + ((notificationObjects?[indexPath.row].hour ?? 0 >= 12) ? "PM" : "AM")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? NotificationEditorViewController, let selectedRow = stopNotificationTableView.indexPathForSelectedRow
        {
            destination.stopNotification = notificationObjects![selectedRow.row]
        }
    }
    
    @IBAction func unwindFromNotificationEditorTableView(_ segue: UIStoryboardSegue)
    {
        if let selectedRow = stopNotificationTableView.indexPathForSelectedRow
        {
            configureCell(cell: stopNotificationTableView.cellForRow(at: selectedRow)!, indexPath: selectedRow)
            stopNotificationTableView.deselectRow(at: selectedRow, animated: true)
        }
    }
    
    @objc @IBAction func editButtonPressed(_ sender: Any) {
        isEditingTableView = !isEditingTableView
        
        stopNotificationTableView.setEditing(isEditingTableView, animated: true)
        
        notificationNavigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: isEditingTableView ? UIBarButtonItem.SystemItem.save : UIBarButtonItem.SystemItem.edit, target: self, action: #selector(editButtonPressed(_:)))
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        CoreDataStack.persistentContainer.viewContext.delete(notificationObjects![indexPath.row])
        CoreDataStack.saveContext()
        notificationObjects?.remove(at: indexPath.row)
        
        tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.fade)
    }
}
