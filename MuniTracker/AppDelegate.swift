//
//  AppDelegate.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import CloudKit
import UserNotifications

enum ThemeType: Int
{
    case light
    case dark
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    var mainMapViewController: MainMapViewController?
    var shortcutItemToProcess: UIApplicationShortcutItem?
    var routeStopToOpen: (stopTag: String, routeTag: String)?
    
    var firstLaunch = false
    var hasDownloadedData: Bool = !(UserDefaults.standard.object(forKey: "hasDownloadedData") == nil)
    {
        didSet
        {
            if hasDownloadedData
            {
                UserDefaults.standard.set(618, forKey: "hasDownloadedData")
            }
            else
            {
                UserDefaults.standard.set(nil, forKey: "hasDownloadedData")
            }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        mainMapViewController = window?.rootViewController as? MainMapViewController
        
        if UserDefaults.standard.object(forKey: "firstLaunch") == nil
        {
            firstLaunch = true
            UserDefaults.standard.set(618, forKey: "firstLaunch")
            
            if #available(iOS 13.0, *)
            {
                UserDefaults.standard.set(618, forKey: "transitionedToCD-CloudKit")
            }
            else
            {
                CloudManager.addFavoritesZone()
            }
        }
        
        NotificationManager.addObservationNotifications()
        
        if #available(iOS 13.0, *), UserDefaults.standard.object(forKey: "transitionedToCD-CloudKit") == nil
        {
            if let favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [NSManagedObject]
            {
                for favoriteStop in favoriteStops
                {
                    CoreDataStack.persistentContainer.viewContext.delete(favoriteStop)
                }
            }
            
            CloudManager.currentChangeToken = nil
            CloudManager.fetchChangesFromCloud()
            
            UserDefaults.standard.set(618, forKey: "transitionedToCD-CloudKit")
        }
        
        if RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", "0"), moc: CoreDataStack.persistentContainer.viewContext)?.count == 0
        {
            let newGroup = NSEntityDescription.insertNewObject(forEntityName: "FavoriteStopGroup", into: CoreDataStack.persistentContainer.viewContext) as! FavoriteStopGroup
            newGroup.groupName = "Groups"
            newGroup.uuid = "0"
            
            CoreDataStack.saveContext()
        }
        
        FavoriteState.selectedGroupUUID = "0"
        
        if #available(iOS 13.0, *) {}
        else
        {
            if let lastServerChangeToken = UserDefaults.standard.object(forKey: "LastServerChangeToken") as? Data
            {
                CloudManager.currentChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: lastServerChangeToken)
            }
            
            CloudManager.fetchChangesFromCloud()
        }
        
        if let favoritesOrganizeTypeInt = UserDefaults.standard.object(forKey: "FavoritesOrganizeType") as? Int
        {
            FavoriteState.favoritesOrganizeType = FavoriteState.FavoritesOrganizeType(rawValue: favoritesOrganizeTypeInt) ?? .list
        }
                
        if let notificationChangesData = UserDefaults.standard.object(forKey: "notificationChanges") as? Data
        {
            let notificationChanges = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(notificationChangesData) as? Dictionary<String,NotificationChangeType>) ?? [:]
            NotificationManager.notificationChanges = notificationChanges
        }
        
        NotificationManager.syncNotificationChangesToServer()
        
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem
        {
            shortcutItemToProcess = shortcutItem
        }
                
        if let remoteNotification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable : Any], let stopTag = remoteNotification["stop"] as? String, let routeTag = remoteNotification["route"] as? String
        {
            routeStopToOpen = (stopTag: stopTag, routeTag: routeTag)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NotificationManager.syncNotificationChangesToServer()
        
        let notificationChangesData = try? NSKeyedArchiver.archivedData(withRootObject: NotificationManager.notificationChanges, requiringSecureCoding: false)
        UserDefaults.standard.set(notificationChangesData, forKey: "notificationChanges")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if let shortcutItem = shortcutItemToProcess
        {
            switch shortcutItem.type
            {
            case "FavoriteAction":
                mainMapViewController?.performSegue(withIdentifier: "showFavoritesTableView", sender: self)
            case "NearbyAction":
                mainMapViewController?.performSegue(withIdentifier: "showNearbyStopTableView", sender: self)
            default:
                break
            }
            
            shortcutItemToProcess = nil
        }
        
        if let routeStop = routeStopToOpen, let route = RouteDataManager.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeStop.routeTag), moc: CoreDataStack.persistentContainer.viewContext) as? Route, let directions = route.directions?.array as? [Direction]
        {
            var directionTag = ""
            for direction in directions
            {
                if let stops = direction.stops?.array as? [Stop], stops.contains(where: { (stop) -> Bool in
                    return (stop.tag ?? "") == routeStop.stopTag
                })
                {
                    directionTag = direction.tag ?? ""
                    break
                }
            }
            
            MapState.routeInfoShowing = .stop
            MapState.selectedDirectionTag = directionTag
            MapState.selectedStopTag = routeStop.stopTag
            MapState.routeInfoObject = MapState.getCurrentDirection()
            
            mainMapViewController?.showPickerView()
            mainMapViewController?.reloadAllAnnotations()
            
            NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
            
            routeStopToOpen = nil
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        
        CoreDataStack.saveContext()
                
        let notificationChangesData = try? NSKeyedArchiver.archivedData(withRootObject: NotificationManager.notificationChanges, requiringSecureCoding: false)
        UserDefaults.standard.set(notificationChangesData, forKey: "notificationChanges")
    }
    
    func getCurrentTheme() -> ThemeType
    {
        let themeType: ThemeType = (UIScreen.main.traitCollection.userInterfaceStyle == .dark) ? .dark : .light
        return themeType
    }
    
    func updateAppIcon()
    {
        switch UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 1
        {
        case 1:
            UIApplication.shared.setAlternateIconName(nil) { (error) in
                if error != nil
                {
                    print(error!.localizedDescription)
                }
            }
        case 2:
            UIApplication.shared.setAlternateIconName("AppIcon-2") { (error) in
                if error != nil
                {
                    print(error!.localizedDescription)
                }
            }
        default:
            break
        }
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            (granted, error) in
            print("Permission granted: \(granted)")
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // 1. Convert device token to string
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        // 2. Print device token to use for PNs payloads
        print("Device Token: \(token)")
        
        UserDefaults.standard.set(token, forKey: "deviceToken")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 1. Print out error if PNs registration not successful
        print("Failed to register for remote notifications with error: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let stopTag = userInfo["stop"] as? String, let routeTag = userInfo["route"] as? String
        {
            routeStopToOpen = (stopTag: stopTag, routeTag: routeTag)
        }
    }
}

