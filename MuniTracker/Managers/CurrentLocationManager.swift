//
//  CurrentLocationDelegate.swift
//  MuniTracker
//
//  Created by jackson on 6/24/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreLocation

class CurrentLocationManager: NSObject, CLLocationManagerDelegate
{
    let locationManager = CLLocationManager()
    var lastLocation: CLLocation?
    var observersWaitingForUpdates = Array<String>()
    
    func requestCurrentLocation()
    {
        self.locationManager.requestWhenInUseAuthorization()
                
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue = manager.location else { return }
        
        lastLocation = locValue
        
        for observer in observersWaitingForUpdates
        {
            NotificationCenter.default.post(name: NSNotification.Name("UpdatedCurrentLocation:" + observer), object: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
}
