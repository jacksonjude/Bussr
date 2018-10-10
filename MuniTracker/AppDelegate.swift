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
    
    var firstLaunch = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        mainMapViewController = window?.rootViewController as? MainMapViewController
        
        if UserDefaults.standard.object(forKey: "firstLaunch") == nil
        {
            firstLaunch = true
            UserDefaults.standard.set(618, forKey: "firstLaunch")
            
            UserDefaults.standard.set(ThemeType.light.rawValue, forKey: "theme")
            CloudManager.addFavoritesZone()
        }
        
        if let lastServerChangeToken = UserDefaults.standard.object(forKey: "LastServerChangeToken") as? Data
        {
            CloudManager.currentChangeToken = NSKeyedUnarchiver.unarchiveObject(with: lastServerChangeToken) as? CKServerChangeToken
        }
        
        CloudManager.fetchChangesFromCloud()
        
        if let favoritesOrganizeTypeInt = UserDefaults.standard.object(forKey: "FavoritesOrganizeType") as? Int
        {
            FavoriteState.favoritesOrganizeType = FavoriteState.FavoritesOrganizeType(rawValue: favoritesOrganizeTypeInt) ?? .list
        }
                        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        CoreDataStack.saveContext()
    }
    
    func getCurrentTheme() -> ThemeType
    {
        return (UserDefaults.standard.object(forKey: "theme") as? Int).map { ThemeType(rawValue: $0) ?? .light } ?? .light
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

}

