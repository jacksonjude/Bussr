//
//  CloudManager.swift
//  MuniTracker
//
//  Created by jackson on 6/30/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import MapKit

enum ManagedObjectChangeType: Int
{
    case insert
    case delete
}

class CloudManager
{
    static var currentChangeToken: CKServerChangeToken?
    {
        didSet
        {
            UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: self.currentChangeToken as Any), forKey: "LastServerChangeToken")
        }
    }
    static var isReceivingFromServer = false
    static let favoriteStopZone = CKRecordZone(zoneName: "FavoriteStopZone")
    static let privateDatabase = CKContainer.default().privateCloudDatabase
    
    static func fetchChangesFromCloud()
    {
        print("↓ - Fetching Changes from Cloud")
        
        isReceivingFromServer = true
        
        let zoneChangeoptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
        zoneChangeoptions.previousServerChangeToken = currentChangeToken
        
        let fetchRecordChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [favoriteStopZone.zoneID], optionsByRecordZoneID: [favoriteStopZone.zoneID:zoneChangeoptions])
        fetchRecordChangesOperation.fetchAllChanges = true
        
        fetchRecordChangesOperation.recordChangedBlock = {(record) in
            let updateLocalObjectPredicate = NSPredicate(format: "uuid == %@", record.recordID.recordName)
            if let recordToUpdate = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: updateLocalObjectPredicate, moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStop
            {
                recordToUpdate.directionTag = record.value(forKey: "directionTag") as? String
                recordToUpdate.stopTag = record.value(forKey: "stopTag") as? String
                
                print(" ↓ - Updating: \(recordToUpdate.uuid!)")
            }
            else
            {
                let newFavoriteStop = FavoriteStop(context: CoreDataStack.persistentContainer.viewContext)
                newFavoriteStop.uuid = record.recordID.recordName
                newFavoriteStop.directionTag = record.value(forKey: "directionTag") as? String
                newFavoriteStop.stopTag = record.value(forKey: "stopTag") as? String
                
                print(" ↓ - Inserting: \(newFavoriteStop.uuid!)")
            }
        }
        
        fetchRecordChangesOperation.recordWithIDWasDeletedBlock = {(recordID, string) in
            let deleteLocalObjectPredicate = NSPredicate(format: "uuid == %@", recordID.recordName)
            
            if let recordToDelete = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: deleteLocalObjectPredicate, moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStop
            {
                print(" ↓ - Deleting: \(recordToDelete.uuid!)")
                
                OperationQueue.main.addOperation {
                    CoreDataStack.persistentContainer.viewContext.delete(recordToDelete)
                    CoreDataStack.saveContext()
                }
            }
        }
        
        fetchRecordChangesOperation.recordZoneFetchCompletionBlock = {(recordZoneID, serverChangeToken, data, bool, error) in
            if error != nil
            {
                print("Error: \(String(describing: error))")
            }
            else
            {
                self.currentChangeToken = serverChangeToken
                UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: self.currentChangeToken as Any), forKey: "currentChangeToken")
            }
            
            OperationQueue.main.addOperation {
                CoreDataStack.saveContext()
            }
        }
        
        fetchRecordChangesOperation.completionBlock = { () in
            OperationQueue.main.addOperation {
                self.isReceivingFromServer = false
                
                print("↓ - Finished Fetching Changes from Cloud")
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "FinishedFetchingFromCloud"), object: nil)
            }
        }
        
        privateDatabase.add(fetchRecordChangesOperation)
    }
    
    static var queuedChanges = Array<(type: ManagedObjectChangeType, uuid: String)>()
    
    static func addToLocalChanges(type: ManagedObjectChangeType, uuid: String)
    {
        queuedChanges.append((type: type, uuid: uuid))
    }
    
    static func syncToCloud()
    {
        DispatchQueue.global(qos: .background).async {
            let syncToCloudGroup = DispatchGroup()
            for change in queuedChanges
            {
                syncToCloudGroup.enter()
                switch change.type
                {
                case .insert:
                    print(" ↑ - Inserting: \(change.uuid)")
                    
                    let remoteID = CKRecord.ID(recordName: change.uuid, zoneID: favoriteStopZone.zoneID)
                    
                    let remoteRecord = CKRecord(recordType: "FavoriteStop", recordID: remoteID)
                    
                    let newPredicate = NSPredicate(format: "uuid == %@", change.uuid)
                    if let managedObject = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: newPredicate, moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStop
                    {
                        remoteRecord.setValue(managedObject.directionTag, forKey: "directionTag")
                        remoteRecord.setValue(managedObject.stopTag, forKey: "stopTag")
                        
                        privateDatabase.save(remoteRecord, completionHandler: { (record, error) -> Void in
                            if (error != nil) {
                                print("Error: \(String(describing: error))")
                            }
                            else if queuedChanges.count > 0
                            {
                                queuedChanges.removeFirst()
                            }
                            
                            syncToCloudGroup.leave()
                        })
                    }
                case .delete:
                    print(" ↑ - Deleting: \(change.uuid)")
                    privateDatabase.delete(withRecordID: CKRecord.ID(recordName: change.uuid, zoneID: favoriteStopZone.zoneID), completionHandler: { (recordID, error) -> Void in
                        if error != nil
                        {
                            print("Error: \(String(describing: error))")
                        }
                        else if queuedChanges.count > 0
                        {
                            queuedChanges.removeFirst()
                        }
                        
                        syncToCloudGroup.leave()
                    })
                }
                
                syncToCloudGroup.wait()
            }
        }
    }
    
    static func addFavoritesZone()
    {
        let modifyRecordZonesOperations = CKModifyRecordZonesOperation(recordZonesToSave: [favoriteStopZone], recordZoneIDsToDelete: nil)
        privateDatabase.add(modifyRecordZonesOperations)
    }
}
