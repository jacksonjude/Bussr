//
//  CoreDataStack.swift
//  Bussr
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class CoreDataStack {
    static let localRouteEntityTypes = ["Agency", "Route", "Direction", "Stop"]
    static let cloudEntityTypes = ["FavoriteStop", "FavoriteStopGroup", "RecentStop", "StopNotification"]
    
    // MARK: - Core Data stack
    
    static var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        var container: NSPersistentContainer
        
        if #available(iOS 13.0, *) {
            container = NSPersistentCloudKitContainer(name: "Bussr")
        } else {
            container = NSPersistentContainer(name: "Bussr")
        }
        
        let cloudPrivateStoreDescription = NSPersistentStoreDescription()
        cloudPrivateStoreDescription.configuration = "Cloud_Private"
        cloudPrivateStoreDescription.shouldInferMappingModelAutomatically = true
        cloudPrivateStoreDescription.shouldMigrateStoreAutomatically = true
        cloudPrivateStoreDescription.url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jacksonjude.Bussr")!.appendingPathComponent("Bussr_Cloud.sqlite")
        if #available(iOS 13.0, *) {
            cloudPrivateStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.jacksonjude.Bussr")
        }
        
        let cloudPublicStoreDescription = NSPersistentStoreDescription()
        cloudPublicStoreDescription.configuration = "Cloud_Public"
        cloudPublicStoreDescription.shouldInferMappingModelAutomatically = true
        cloudPublicStoreDescription.shouldMigrateStoreAutomatically = true
        cloudPublicStoreDescription.url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jacksonjude.Bussr")!.appendingPathComponent("Bussr_Cloud_Public.sqlite")
        if #available(iOS 14.0, *) {
            cloudPublicStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.jacksonjude.Bussr")
            cloudPublicStoreDescription.cloudKitContainerOptions?.databaseScope = CKDatabase.Scope.public            
        }
        
        var firstLaunch = false
        if UserDefaults.standard.object(forKey: "firstLaunchData") == nil
        {
            firstLaunch = true
            UserDefaults.standard.set(618, forKey: "firstLaunchData")
        }
        
        if firstLaunch
        {
            copyPreloadedRouteData()
        }
        
        let localStoreDescription = NSPersistentStoreDescription()
        localStoreDescription.configuration = "Local"
        localStoreDescription.shouldInferMappingModelAutomatically = true
        localStoreDescription.shouldMigrateStoreAutomatically = true
        localStoreDescription.url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jacksonjude.Bussr")!.appendingPathComponent("Bussr.sqlite")
        
        container.persistentStoreDescriptions = [localStoreDescription, cloudPrivateStoreDescription, cloudPublicStoreDescription]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    static func decodeArrayFromJSON(object: NSManagedObject, field: String) -> Array<Any>?
    {
        if let JSONdata = object.value(forKey: field) as? Data
        {
            do
            {
                let array = try JSONSerialization.jsonObject(with: JSONdata, options: .allowFragments) as? Array<Any>
                return array
            }
            catch
            {
                print(error)
                return nil
            }
        }
        
        return nil
    }
    
    static func copyPreloadedRouteData()
    {
        let sqlitePath = Bundle.main.path(forResource: "Bussr", ofType: "sqlite")
        let originURL = URL(fileURLWithPath: sqlitePath!)
        let destinationURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jacksonjude.Bussr")!.appendingPathComponent("Bussr.sqlite")
        
        if !FileManager.default.fileExists(atPath: destinationURL.absoluteString) {
            do {
                try FileManager.default.copyItem(at: originURL, to: destinationURL)
                
                print("Preloaded route file copied")
            } catch {
                print("Preloaded route file copy error: \(error)")
            }
        } else {
            print("CoreData route database already exists")
        }
    }
    
    // MARK: - Core Data Saving support
    
    static func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    //MARK: - Clear All Data
    
    static func clearData(entityTypes: [String]) -> String {
        var deletionLogs = ""
        
        for entityType in entityTypes
        {
            if let objects = RouteDataManager.fetchLocalObjects(type: entityType, predicate: NSPredicate(value: true), moc: CoreDataStack.persistentContainer.viewContext) as? [NSManagedObject]
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
        
        return deletionLogs
    }
}
