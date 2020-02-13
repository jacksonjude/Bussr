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

enum OnLaunchType: Int
{
    case none
    case favorites
    case nearby
    case recents
}

class SettingsViewController: UITableViewController
{
    @IBOutlet weak var onLaunchLabel: UILabel!
    @IBOutlet weak var locationSortTypeLabel: UILabel!
    @IBOutlet weak var appIconLabel: UILabel!
    @IBOutlet weak var predictionRefreshTimeLabel: UILabel!
    
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    
    //MARK: - View
    
    override func viewDidLoad() {
        setupThemeElements()
                
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        setLocationSortTypeTitle(locationSortType: locationSortType)
        
        let appIcon = UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        setAppIconTitle(appIcon: appIcon)
        
        let refreshTime = UserDefaults.standard.object(forKey: "PredictionRefreshTime") as? Double ?? 60.0
        setPredictionRefreshTimeTitle(refreshTime: refreshTime)
        
        let onLaunchType: OnLaunchType = (UserDefaults.standard.object(forKey: "OnLaunchType") as? Int).map { OnLaunchType(rawValue: $0)  ?? .none } ?? .none
        setOnLaunchTypeTitle(onLaunchType: onLaunchType)
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch tableView.cellForRow(at: indexPath)!.reuseIdentifier ?? ""
        {
        case "OnLaunchCell":
            setOnLaunch(tableView)
        case "PredictionRefreshCell":
            setPredictionRefreshTime(tableView)
        case "AppIconCell":
            toggleAppIcon(tableView)
        case "UpdateRoutesCell":
            updateRoutes(tableView)
        case "ClearRoutesCell":
            clearRoutes(tableView)
        case "LocationFilterCell":
            toggleLocationSortType(tableView)
        default:
            break
        }
    }
    
    //MARK: - Manage Routes
    
    func updateRoutes(_ sender: Any) {
        progressAlertView = UIAlertController(title: "Updating", message: "Updating route data...\n", preferredStyle: .alert)
        //progressAlertView!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(progressAlertView!, animated: true, completion: {
            let margin: CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
            self.progressView = UIProgressView(frame: rect)
            self.progressView!.tintColor = UIColor.blue
            self.progressAlertView!.view.addSubview(self.progressView!)
            
            CoreDataStack.saveContext()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.addToProgress(notification:)), name: NSNotification.Name("CompletedRoute"), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.dismissAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            DispatchQueue.global(qos: .background).async
                {
                    RouteDataManager.updateAllData()
            }
        })
        
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        setLocationSortTypeTitle(locationSortType: locationSortType)
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
    
    func clearRoutes(_ sender: Any) {
        let entityTypes = ["Agency", "Route", "Direction", "Stop", "FavoriteStop"]
        
        var deletionLogs = ""
        
        for entityType in entityTypes
        {
            if let objects = RouteDataManager.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [NSManagedObject]
            {
                for object in objects
                {
                    CoreDataStack.persistentContainer.viewContext.delete(object)
                }
                
                deletionLogs += "Deleted " + String(objects.count) + " " + entityType + "\n"
            }
            else
            {
                deletionLogs += "Deleted 0 " + entityType + "\n"
            }
        }
        
        deletionLogs = String(deletionLogs.dropLast())
        
        CoreDataStack.saveContext()
        
        let deletionAlertView = UIAlertController(title: "Deleted All Data", message: deletionLogs, preferredStyle: .alert)
        deletionAlertView.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alert) in
            
        }))
        print(deletionLogs)
        
        UserDefaults.standard.set(nil, forKey: "LastServerChangeToken")
        CloudManager.currentChangeToken = nil
        
        self.present(deletionAlertView, animated: true, completion: nil)
    }
    
    //MARK: - Other Buttons
    
    func toggleLocationSortType(_ sender: Any) {
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        
        switch locationSortType
        {
        case .selectClosest:
            UserDefaults.standard.set(LocationSortType.fullSort.rawValue, forKey: "LocationSortType")
            setLocationSortTypeTitle(locationSortType: .fullSort)
        case .fullSort:
            UserDefaults.standard.set(LocationSortType.selectClosest.rawValue, forKey: "LocationSortType")
            setLocationSortTypeTitle(locationSortType: .selectClosest)
        }
    }
    
    func toggleAppIcon(_ sender: Any) {
        let appIcon = UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        
        switch appIcon
        {
        case 1:
            UserDefaults.standard.set(2, forKey: "AppIcon")
            setAppIconTitle(appIcon: 2)
        case 2:
            UserDefaults.standard.set(1, forKey: "AppIcon")
            setAppIconTitle(appIcon: 1)
        default:
            break
        }
        
        appDelegate.updateAppIcon()
    }
    
    func setPredictionRefreshTime(_ sender: Any) {
        var refreshTime = UserDefaults.standard.object(forKey: "PredictionRefreshTime") as? Double ?? 60.0
        
        let possibleRefreshTimes = [0.0, 15.0, 30.0, 60.0]
        if let refreshTimeIndex = possibleRefreshTimes.firstIndex(of: refreshTime), refreshTimeIndex+1 < possibleRefreshTimes.count
        {
            refreshTime = possibleRefreshTimes[refreshTimeIndex+1]
        }
        else
        {
            refreshTime = possibleRefreshTimes[0]
        }
        UserDefaults.standard.set(refreshTime, forKey: "PredictionRefreshTime")
        
        setPredictionRefreshTimeTitle(refreshTime: refreshTime)
    }
    
    func setOnLaunch(_ sender: Any) {
        var onLaunchTypeInt = UserDefaults.standard.object(forKey: "OnLaunchType") as? Int ?? 0
        onLaunchTypeInt += 1
        
        if onLaunchTypeInt > 4-1
        {
            onLaunchTypeInt = 0
        }
                
        let onLaunchType = OnLaunchType(rawValue: onLaunchTypeInt) ?? .none
        UserDefaults.standard.set(onLaunchType.rawValue, forKey: "OnLaunchType")
        
        setOnLaunchTypeTitle(onLaunchType: onLaunchType)
    }
    
    //MARK: - Set Titles
    
    func setLocationSortTypeTitle(locationSortType: LocationSortType)
    {
        switch locationSortType
        {
        case .fullSort:
            locationSortTypeLabel.text = "Full Sort"
        case .selectClosest:
            locationSortTypeLabel.text = "Select Closest"
        }
    }
    
    func setAppIconTitle(appIcon: Int)
    {
        appIconLabel.text = "Icon " + String(appIcon)
    }
    
    func setPredictionRefreshTimeTitle(refreshTime: Double)
    {
        predictionRefreshTimeLabel.text = String(Int(refreshTime)) + "s"
    }
    
    func setOnLaunchTypeTitle(onLaunchType: OnLaunchType)
    {
        var onLaunchTypeText = "None"
        switch onLaunchType
        {
        case .none:
            onLaunchTypeText = "None"
        case .favorites:
            onLaunchTypeText = "Favorites"
        case .nearby:
            onLaunchTypeText = "Nearby"
        case .recents:
            onLaunchTypeText = "Recents"
        }
        
        onLaunchLabel.text = onLaunchTypeText
    }
}
