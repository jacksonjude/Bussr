//
//  SettingsViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/25/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

enum LocationSortType: Int
{
    case fullSort
    case selectClosest
}

enum FavoritesSortType: Int
{
    case location
    case list
}

class SettingsViewController: UIViewController
{
    @IBOutlet weak var favoritesSortedByButton: UIButton!
    @IBOutlet weak var locationSortTypeButton: UIButton!
    
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    
    @IBAction func updateRoutes(_ sender: Any) {
        progressAlertView = UIAlertController(title: "Updating", message: "Updating route data...\n", preferredStyle: .alert)
        //progressAlertView!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(progressAlertView!, animated: true, completion: {
            let margin: CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
            self.progressView = UIProgressView(frame: rect)
            self.progressView!.tintColor = UIColor.blue
            self.progressAlertView!.view.addSubview(self.progressView!)
            
            appDelegate.saveContext()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.addToProgress(notification:)), name: NSNotification.Name("CompletedRoute"), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.dismissAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            DispatchQueue.global(qos: .background).async
                {
                    RouteDataManager.updateAllData()
            }
        })
        
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        let favoritesSortType: FavoritesSortType = (UserDefaults.standard.object(forKey: "FavoritesSortType") as? Int).map { FavoritesSortType(rawValue: $0) ?? .location } ?? .location
        
        setLocationSortTypeButtonTitle(locationSortType: locationSortType)
        setFavoritesSortedByButtonTitle(favoritesSortType: favoritesSortType)
    }
    
    @objc func addToProgress(notification: Notification)
    {
        OperationQueue.main.addOperation {
            self.progressView?.progress = notification.userInfo?["progress"] as? Float ?? 0.0
        }
    }
    
    @objc func dismissAlertView()
    {
        progressAlertView?.dismiss(animated: true, completion: {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CompletedRoute"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
        })
    }
    
    @IBAction func clearRoutes(_ sender: Any) {
        let entityTypes = ["Agency", "Route", "Direction", "Stop"]
        
        var deletionLogs = ""
        
        for entityType in entityTypes
        {
            if let objects = RouteDataManager.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "TRUEPREDICATE"), moc: appDelegate.persistentContainer.viewContext) as? [NSManagedObject]
            {
                for object in objects
                {
                    appDelegate.persistentContainer.viewContext.delete(object)
                }
                
                deletionLogs += "Deleted " + String(objects.count) + " " + entityType + "\n"
            }
            else
            {
                deletionLogs += "Deleted 0 " + entityType + "\n"
            }
        }
        
        deletionLogs = String(deletionLogs.dropLast())
        
        appDelegate.saveContext()
        
        let deletionAlertView = UIAlertController(title: "Deleted All Data", message: deletionLogs, preferredStyle: .alert)
        deletionAlertView.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alert) in
            
        }))
        print(deletionLogs)
        
        self.present(deletionAlertView, animated: true, completion: nil)
    }
    
    @IBAction func toggleFavoritesSortType(_ sender: Any) {
        let favoritesSortType: FavoritesSortType = (UserDefaults.standard.object(forKey: "FavoritesSortType") as? Int).map { FavoritesSortType(rawValue: $0) ?? .location } ?? .location
        
        switch favoritesSortType
        {
        case .list:
            UserDefaults.standard.set(FavoritesSortType.location.rawValue, forKey: "FavoritesSortType")
            setFavoritesSortedByButtonTitle(favoritesSortType: .location)
        case .location:
            UserDefaults.standard.set(FavoritesSortType.list.rawValue, forKey: "FavoritesSortType")
            setFavoritesSortedByButtonTitle(favoritesSortType: .list)
        }
    }
    
    @IBAction func toggleLocationSortType(_ sender: Any) {
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        
        switch locationSortType
        {
        case .selectClosest:
            UserDefaults.standard.set(LocationSortType.fullSort.rawValue, forKey: "LocationSortType")
            setLocationSortTypeButtonTitle(locationSortType: .fullSort)
        case .fullSort:
            UserDefaults.standard.set(LocationSortType.selectClosest.rawValue, forKey: "LocationSortType")
            setLocationSortTypeButtonTitle(locationSortType: .selectClosest)
        }
    }
    
    func setFavoritesSortedByButtonTitle(favoritesSortType: FavoritesSortType)
    {
        switch favoritesSortType
        {
        case .location:
            favoritesSortedByButton.setTitle("Favorites Sorted By - " + "Location", for: UIControl.State.normal)
        case .list:
            favoritesSortedByButton.setTitle("Favorites Sorted By - " + "List", for: UIControl.State.normal)
        }
    }
    
    func setLocationSortTypeButtonTitle(locationSortType: LocationSortType)
    {
        switch locationSortType
        {
        case .fullSort:
            locationSortTypeButton.setTitle("Location - " + "Full Sort", for: UIControl.State.normal)
        case .selectClosest:
            locationSortTypeButton.setTitle("Location - " + "Select Closest", for: UIControl.State.normal)
        }
    }
}
