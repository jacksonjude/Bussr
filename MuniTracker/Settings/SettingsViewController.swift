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

class SettingsViewController: UITableViewController
{
    @IBOutlet weak var locationSortTypeLabel: UILabel!
    @IBOutlet weak var appIconLabel: UILabel!
    @IBOutlet weak var predictionRefreshTimeLabel: UILabel!
    @IBOutlet weak var lastUpdatedRoutesLabel: UILabel!
    @IBOutlet weak var nearbyMenuCollapseTypeLabel: UILabel!
    
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    var routeOnLabel: UILabel?
    
    //MARK: - View
    
    override func viewDidLoad() {
        setupThemeElements()
                
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        setLocationSortTypeTitle(locationSortType: locationSortType)
        
        let collapseRoutes = UserDefaults.standard.object(forKey: "ShouldCollapseRoutes") as? Bool ?? true
        setNearbyCollapseTypeTitle(shouldCollapseRoutes: collapseRoutes)
        
        let appIcon = UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        setAppIconTitle(appIcon: appIcon)
        
        let refreshTime = UserDefaults.standard.object(forKey: "PredictionRefreshTime") as? Double ?? 60.0
        setPredictionRefreshTimeTitle(refreshTime: refreshTime)
        
        setLastUpdatedRoutesLabel()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setLastUpdatedRoutesLabel), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
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
        case "NearbyMenu":
            toggleNearbyCollapseType(tableView)
        default:
            break
        }
    }
    
    //MARK: - Manage Routes
    
    func updateRoutes(_ sender: Any) {
        progressAlertView = UIAlertController(title: "Updating Routes", message: "\n\n", preferredStyle: .alert)
        progressAlertView!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(progressAlertView!, animated: true, completion: {
            let margin: CGFloat = 8.0
            
            let routeOnLabelRect = CGRect(x: 0, y: 60.0, width: self.progressAlertView!.view.frame.width, height: 20)
            self.routeOnLabel = UILabel(frame: routeOnLabelRect)
            self.routeOnLabel!.textAlignment = .center
            self.progressAlertView!.view.addSubview(self.routeOnLabel!)
            
            let progressViewRect = CGRect(x: margin, y: 88.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
            self.progressView = UIProgressView(frame: progressViewRect)
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
            self.routeOnLabel?.text = notification.userInfo?["route"] as? String
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
        let deletionLogs = CoreDataStack.clearData(entityTypes: CoreDataStack.localRouteEntityTypes)
        
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
    
    func toggleNearbyCollapseType(_ sender: Any)
    {
        let collapseRoutes = UserDefaults.standard.object(forKey: "ShouldCollapseRoutes") as? Bool ?? true
        
        UserDefaults.standard.set(!collapseRoutes, forKey: "ShouldCollapseRoutes")
        
        setNearbyCollapseTypeTitle(shouldCollapseRoutes: !collapseRoutes)
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
        if refreshTime == 0.0
        {
            predictionRefreshTimeLabel.text = "None"
        }
    }
    
    @objc func setLastUpdatedRoutesLabel()
    {
        let lastUpdatedRoutes = UserDefaults.standard.object(forKey: "RoutesUpdatedAt") as? Date ?? Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd hh:mm"
        
        lastUpdatedRoutesLabel.text = dateFormatter.string(from: lastUpdatedRoutes)
    }
    
    func setNearbyCollapseTypeTitle(shouldCollapseRoutes: Bool)
    {
        if shouldCollapseRoutes
        {
            nearbyMenuCollapseTypeLabel.text = "Each Route"
        }
        else
        {
            nearbyMenuCollapseTypeLabel.text = "All Stops"
        }
    }
}
