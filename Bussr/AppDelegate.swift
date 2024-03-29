//
//  AppDelegate.swift
//  Bussr
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import CloudKit
import UserNotifications
import BackgroundTasks

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
        }
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let lastVersion = UserDefaults.standard.object(forKey: "version") as? String
        
        if !firstLaunch, let appVersion = appVersion, lastVersion != appVersion
        {
            UserDefaults.standard.set(appVersion, forKey: "version")
            print("Clearing data for \(lastVersion ?? "nil") -> \(appVersion)")
            
            hasDownloadedData = false
            _ = CoreDataStack.clearData(entityTypes: CoreDataStack.localRouteEntityTypes)
        }
        
        FavoriteState.selectedGroupUUID = "0"
        
        if let favoritesOrganizeTypeInt = UserDefaults.standard.object(forKey: "FavoritesOrganizeType") as? Int
        {
            FavoriteState.favoritesOrganizeType = FavoriteState.FavoritesOrganizeType(rawValue: favoritesOrganizeTypeInt) ?? .list
        }
        
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem
        {
            shortcutItemToProcess = shortcutItem
        }
                
        if let remoteNotification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable : Any], let stopTag = remoteNotification["stop"] as? String, let routeTag = remoteNotification["route"] as? String
        {
            routeStopToOpen = (stopTag: stopTag, routeTag: routeTag)
        }
        
        application.registerForRemoteNotifications()
        
        registerRouteUpdateBackgroundTask()
        
        return true
    }
    
    func registerRouteUpdateBackgroundTask()
    {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.jacksonjude.Bussr.update_route_data", using: nil) { task in
            RouteDataManager.executeRouteUpdateBackgroundTask(task: task)
        }
        
        if UserDefaults.standard.object(forKey: "NextRouteUpdate") == nil
        {
            RouteDataManager.submitNextRouteUpdateBackgroundTask()
        }
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        NotificationCenter.default.post(name: NSNotification.Name("StopPredictionRefresh"), object: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NotificationCenter.default.post(name: NSNotification.Name("StopPredictionRefresh"), object: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        NotificationCenter.default.post(name: NSNotification.Name("StartPredictionRefresh"), object: nil)
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
        
        if let routeStop = routeStopToOpen, let route = CoreDataStack.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeStop.routeTag), moc: CoreDataStack.persistentContainer.viewContext) as? Route, let directions = route.directions?.array as? [Direction]
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
            mainMapViewController?.reloadAllAnnotations(fetchPredictions: false)
            
            NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
            
            routeStopToOpen = nil
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("UpdateCountdownProgressBar"), object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        
        CoreDataStack.saveContext()
    }
    
    func getCurrentTheme() -> ThemeType
    {
        let themeType: ThemeType = (UIScreen.main.traitCollection.userInterfaceStyle == .dark) ? .dark : .light
        return themeType
    }
    
    func updateAppIcon()
    {
        switch UserDefaults.standard.object(forKey: "AppIcon") as? Int ?? 2
        {
        case 2:
            UIApplication.shared.setAlternateIconName(nil) { (error) in
                if error != nil
                {
                    print(error!.localizedDescription)
                }
            }
        case 1:
            UIApplication.shared.setAlternateIconName("AppIcon-1") { (error) in
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

