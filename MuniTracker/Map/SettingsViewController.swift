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
    @IBOutlet weak var themeButton: UIButton!
    @IBOutlet weak var appIconButton: UIButton!
    
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    
    @IBOutlet weak var filterConfigLabel: UILabel!
    @IBOutlet weak var manageRouteDataLabel: UILabel!
    @IBOutlet weak var generalLabel: UILabel!
    
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    
    //MARK: - View
    
    override func viewDidLoad() {
        setupThemeElements()
        
        setThemeButtonTitle(themeType: appDelegate.getCurrentTheme())
        
        let favoritesSortType: FavoritesSortType = (UserDefaults.standard.object(forKey: "FavoritesSortType") as? Int).map { FavoritesSortType(rawValue: $0) ?? .location } ?? .location
        let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
        
        setFavoritesSortedByButtonTitle(favoritesSortType: favoritesSortType)
        setLocationSortTypeButtonTitle(locationSortType: locationSortType)
        
        let appIcon = UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        setAppIconButtonTitle(appIcon: appIcon)
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = offWhite
            self.mainNavigationBar.barTintColor = offWhite
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
            self.filterConfigLabel.textColor = black
            self.generalLabel.textColor = black
            self.manageRouteDataLabel.textColor = black
        case .dark:
            self.view.backgroundColor = black
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
            self.filterConfigLabel.textColor = white
            self.generalLabel.textColor = white
            self.manageRouteDataLabel.textColor = white
        }
    }
    
    //MARK: - Route Manage
    
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
        let entityTypes = ["Agency", "Route", "Direction", "Stop", "FavoriteStop"]
        
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
    
    //MARK: - Other Buttons
    
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
    
    @IBAction func toggleTheme(_ sender: Any) {
        let theme: ThemeType = (UserDefaults.standard.object(forKey: "theme") as? Int).map { ThemeType(rawValue: $0)  ?? .light } ?? .light
        
        switch theme
        {
        case .light:
            UserDefaults.standard.set(ThemeType.dark.rawValue, forKey: "theme")
            setThemeButtonTitle(themeType: .dark)
        case .dark:
            UserDefaults.standard.set(ThemeType.light.rawValue, forKey: "theme")
            setThemeButtonTitle(themeType: .light)
        }
        
        setupThemeElements()
    }
    
    @IBAction func toggleAppIcon(_ sender: Any) {
        let appIcon = UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        
        switch appIcon
        {
        case 1:
            UserDefaults.standard.set(2, forKey: "AppIcon")
            setAppIconButtonTitle(appIcon: 2)
        case 2:
            UserDefaults.standard.set(1, forKey: "AppIcon")
            setAppIconButtonTitle(appIcon: 1)
        default:
            break
        }
        
        appDelegate.updateAppIcon()
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
    
    func setThemeButtonTitle(themeType: ThemeType)
    {
        switch themeType
        {
        case .light:
            themeButton.setTitle("Theme - " + "Light", for: UIControl.State.normal)
        case .dark:
            themeButton.setTitle("Theme - " + "Dark", for: UIControl.State.normal)
        }
    }
    
    func setAppIconButtonTitle(appIcon: Int)
    {
        appIconButton.setTitle("AppIcon - " + String(appIcon), for: UIControl.State.normal)
    }
}
