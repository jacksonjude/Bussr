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
        
        if locationFilterEnabled
        {
            locationFilterEnabled = false
            locationButton.setImage(UIImage(named: "CurrentLocationIcon"), for: UIControl.State.normal)
        }
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
                if let direction = routeInfoToChange[row] as? Direction
                {
                    MapState.selectedDirectionTag = direction.directionTag
                }
            case .stop:
                if let stop = routeInfoToChange[row] as? Stop
                {
                    MapState.selectedStopTag = stop.stopTag
                }
            default:
                break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleFavoriteForSelectedStop), name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
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
            
            if favoriteFilterEnabled
            {
                filterByFavorites()
            }
            
            if locationFilterEnabled
            {
                if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
                {
                    sortStopsByCurrentLocation(location: currentLocation)
                }
            }
            
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
            
            filterByFavorites()
        }
        else
        {
            favoriteButton.setImage(UIImage(named: "FavoriteIcon"), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    @objc func toggleFavoriteForSelectedStop()
    {
        if MapState.routeInfoShowing == .stop
        {
            if let selectedStop = RouteDataManager.getCurrentStop(), let selectedDirection = RouteDataManager.getCurrentDirection()//routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Stop
            {
                let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!, stopTag: selectedStop.stopTag)
                if favoriteStopCallback.count > 0
                {
                    appDelegate.persistentContainer.viewContext.delete(favoriteStopCallback[0])
                }
                else
                {
                    let newFavoriteStop = FavoriteStop(context: appDelegate.persistentContainer.viewContext)
                    newFavoriteStop.directionTag = selectedDirection.directionTag
                    newFavoriteStop.stopTag = selectedStop.stopTag
                }
                
                appDelegate.saveContext()
            }
        }
    }
    
    func filterByFavorites()
    {
        if let selectedDirection = RouteDataManager.getCurrentDirection()
        {
            var favoriteStops = Array<Stop>()
            let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!)
            for favoriteStop in favoriteStopCallback
            {
                let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStop.stopTag!), moc: appDelegate.persistentContainer.viewContext).object as! Stop
                favoriteStops.append(stop)
            }
            
            routeInfoToChange = favoriteStops
            
            routeInfoPicker.reloadAllComponents()
            
            if locationFilterEnabled
            {
                if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
                {
                    sortStopsByCurrentLocation(location: currentLocation)
                }
            }
            else
            {
                routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
            }
            
            pickerSelectedRow()
        }
    }
    
    @IBAction func locationFilterButtonPressed(_ sender: Any) {
        locationFilterEnabled = !locationFilterEnabled
        
        if locationFilterEnabled
        {
            locationButton.setImage(UIImage(named: "CurrentLocationFillIcon"), for: UIControl.State.normal)
            
            if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
            {
                sortStopsByCurrentLocation(location: currentLocation)
            }
            
        }
        else
        {
            locationButton.setImage(UIImage(named: "CurrentLocationIcon"), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    func sortStopsByCurrentLocation(location: CLLocation)
    {
        if let routeStops = routeInfoToChange as? Array<Stop>
        {
            let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: routeStops, locationToTest: location)
            
            let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
            
            switch locationSortType
            {
            case .fullSort:
                routeInfoToChange = sortedStops
                
                routeInfoPicker.reloadAllComponents()
                routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
            case .selectClosest:
                if sortedStops.count > 0
                {
                    routeInfoPicker.selectRow(routeInfoToChange.firstIndex(of: sortedStops[0]) ?? 0, inComponent: 0, animated: true)
                }
            }
            
            pickerSelectedRow()
        }
    }
}
