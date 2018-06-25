//
//  RouteInfoPickerViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreLocation

class RouteInfoPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    var routeInfoToChange = Array<NSManagedObject>()
    @IBOutlet weak var routeInfoPicker: UIPickerView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    
    var favoriteFilterEnabled = false
    var locationFilterEnabled = false
    var waitingForLocation = false
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return routeInfoToChange.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch MapState.routeInfoShowing
        {
        case .none:
            return nil
        case .direction:
            return (routeInfoToChange[row] as? Direction)?.directionTitle
        case .stop:
            return (routeInfoToChange[row] as? Stop)?.stopTitle
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerSelectedRow()
    }
    
    func pickerSelectedRow()
    {
        updateSelectedObjectTags()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":false])
    }
    
    func updateSelectedObjectTags()
    {
        let row = routeInfoPicker.selectedRow(inComponent: 0)
        
        if routeInfoToChange.count > row
        {
            switch MapState.routeInfoShowing
            {
            case .direction:
                MapState.selectedDirectionTag = (routeInfoToChange[row] as! Direction).directionTag
            case .stop:
                MapState.selectedStopTag = (routeInfoToChange[row] as! Stop).stopTag
            default:
                break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @objc func reloadRouteData()
    {
        if MapState.showingPickerView
        {
            routeInfoToChange.removeAll()
            
            switch MapState.routeInfoShowing
            {
            case .none:
                self.view.superview!.isHidden = true
            case .direction:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = (MapState.routeInfoObject as? Route)?.directions?.array as? Array<Direction> ?? Array<Direction>()
                
                disableFilterButtons()
            case .stop:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = (MapState.routeInfoObject as? Direction)?.stops?.array as? Array<Stop> ?? Array<Stop>()
                
                enableFilterButtons()
            }
            
            routeInfoPicker.reloadAllComponents()
            
            routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
            
            updateSelectedObjectTags()
            NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":true])
        }
        else
        {
            self.view.superview!.isHidden = true
        }
    }
    
    @IBAction func directionButtonPressed(_ sender: Any) {
        switch MapState.routeInfoShowing
        {
        case .direction:
            MapState.routeInfoShowing = .stop
            MapState.routeInfoObject = routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Direction
            
            enableFilterButtons()
        case .stop:
            MapState.routeInfoShowing = .direction
            MapState.routeInfoObject = (MapState.routeInfoObject as? Direction)?.route
            
            disableFilterButtons()
        default:
            break
        }
        
        reloadRouteData()
    }
    
    func enableFilterButtons()
    {
        favoriteButton.isHidden = false
        favoriteButton.isEnabled = true
        locationButton.isHidden = false
        locationButton.isEnabled = true
    }
    
    func disableFilterButtons()
    {
        favoriteButton.isHidden = true
        favoriteButton.isEnabled = false
        locationButton.isHidden = true
        locationButton.isEnabled = false
        
        favoriteFilterEnabled = false
        locationFilterEnabled = false
        
        favoriteButton.setImage(UIImage(named: "FavoriteIcon"), for: UIControl.State.normal)
        locationButton.setImage(UIImage(named: "CurrentLocationIcon"), for: UIControl.State.normal)
    }
    
    @IBAction func favoriteFilterButtonPressed(_ sender: Any) {
        favoriteFilterEnabled = !favoriteFilterEnabled
        
        if favoriteFilterEnabled
        {
            favoriteButton.setImage(UIImage(named: "FavoriteFillIcon"), for: UIControl.State.normal)
        }
        else
        {
            favoriteButton.setImage(UIImage(named: "FavoriteIcon"), for: UIControl.State.normal)
        }
    }
    
    @IBAction func locationFilterButtonPressed(_ sender: Any) {
        locationFilterEnabled = !locationFilterEnabled
        
        if locationFilterEnabled
        {
            locationButton.setImage(UIImage(named: "CurrentLocationFillIcon"), for: UIControl.State.normal)
            
            if appDelegate.currentLocationManager.lastLocation == nil
            {
                let locationReturnUUID = UUID().uuidString
                NotificationCenter.default.addObserver(self, selector: #selector(foundCurrentLocation(_:)), name: NSNotification.Name("UpdatedCurrentLocation:" + locationReturnUUID), object: nil)
                appDelegate.currentLocationManager.observersWaitingForUpdates.append(locationReturnUUID)
                waitingForLocation = true
                
                appDelegate.currentLocationManager.requestCurrentLocation()
            }
            else
            {
                foundCurrentLocation()
            }
        }
        else
        {
            locationButton.setImage(UIImage(named: "CurrentLocationIcon"), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    @objc func foundCurrentLocation(_ notification: Notification? = nil)
    {
        waitingForLocation = false
        
        if notification != nil
        {
            appDelegate.currentLocationManager.observersWaitingForUpdates.remove(at: appDelegate.currentLocationManager.observersWaitingForUpdates.firstIndex(of: String(notification!.name.rawValue.split(separator: ":")[1]))!)
        }
        
        if let currentLocation = appDelegate.currentLocationManager.lastLocation
        {
            sortStopsByCurrentLocation(location: currentLocation)
        }
    }
    
    func sortStopsByCurrentLocation(location: CLLocation)
    {
        if let routeStops = routeInfoToChange as? Array<Stop>
        {
            let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: routeStops, locationToTest: location)
            
            enum LocationSortType
            {
                case fullSort
                case selectClosest
            }
            
            let locationSortType: LocationSortType = .selectClosest
            
            switch locationSortType
            {
            case .fullSort:
                routeInfoToChange = sortedStops
                
                routeInfoPicker.reloadAllComponents()
                routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
            case .selectClosest:
                routeInfoPicker.selectRow(routeInfoToChange.firstIndex(of: sortedStops[0]) ?? 0, inComponent: 0, animated: true)
            }
            
            
            pickerSelectedRow()
        }
    }
}
