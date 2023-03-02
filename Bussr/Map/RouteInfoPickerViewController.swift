//
//  RouteInfoPickerViewController.swift
//  Bussr
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
    var routeInfoToChange = Array<Any>()
    @IBOutlet weak var routeInfoPicker: UIPickerView!
    @IBOutlet weak var confirmDirectionButton: UIButton!
    @IBOutlet weak var directionButton: UIButton!
    @IBOutlet weak var otherDirectionsButton: UIButton!
    @IBOutlet weak var addFavoriteButton: UIButton!
    @IBOutlet weak var addNotificationButton: UIButton!
    @IBOutlet weak var expandFiltersButton: UIButton!
    @IBOutlet weak var swipeBar: UIView!
    @IBOutlet weak var routeInfoPickerContainer: UIView!
    
    @IBOutlet weak var panelTipHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var routeInfoPanelBottomMarginConstraint: NSLayoutConstraint!
    
    var waitingForLocation = false
    var filtersExpanded = false
    
    var mainMapViewController: MainMapViewController?

    //MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleFavoriteForSelectedStop), name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableFilters), name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectCurrentStop), name: NSNotification.Name("SelectCurrentStop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(collapseFilters), name: NSNotification.Name("CollapseFilters"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableFilters), name: NSNotification.Name("EnableFilters"), object: nil)
        
        setFavoriteButtonImage(inverse: false)
        setupThemeElements()
        
        panelTipHeightConstraint.constant = DisplayConstants.panelTipSize
        routeInfoPanelBottomMarginConstraint.constant = DisplayConstants.panelBottomMargin
        self.view.layoutIfNeeded()
        
        setupFilterButtons()
        
        reloadRouteData()
    }
    
    func setupFilterButtons()
    {
        let favoriteButton = FilterButton(imagePath: "Favorite", superview: routeInfoPickerContainer)
        let locationButton = FilterButton(imagePath: "CurrentLocation", superview: routeInfoPickerContainer)
        favoriteButton.singleTapHandler = {
            self.favoriteFilterButtonPressed(favoriteButton)
            favoriteButton.filterIsEnabled = MapState.favoriteFilterEnabled
        }
        locationButton.singleTapHandler = {
            self.locationFilterButtonPressed(locationButton)
            locationButton.filterIsEnabled = MapState.locationFilterEnabled
        }
        filterButtons.append(locationButton)
        filterButtons.append(favoriteButton)
    }
    
    var viewDidJustAppear = false
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
        if !viewDidJustAppear
        {
            reloadRouteData()
            viewDidJustAppear = true
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UIApplication.shared.applicationState == .inactive else {
            return
        }

        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            for filterButton in filterButtons
            {
                filterButton.setFilterImage()
            }
            self.confirmDirectionButton.setImage(UIImage(named: "ConfirmIcon"), for: UIControl.State.normal)
            self.directionButton.setImage(UIImage(named: "DirectionIcon"), for: UIControl.State.normal)
            self.otherDirectionsButton.setImage(UIImage(named: "BusStopIcon"), for: UIControl.State.normal)
            self.expandFiltersButton.setImage(UIImage(named: "FilterIcon"), for: UIControl.State.normal)
            self.addNotificationButton.setImage(UIImage(named: "BellAddIcon"), for: UIControl.State.normal)
            setFavoriteButtonImage(inverse: false)
            
            self.view.backgroundColor = UIColor.white.withAlphaComponent(DisplayConstants.mapAlphaValue)
        case .dark:
            for filterButton in filterButtons
            {
                filterButton.setFilterImage()
            }
            self.confirmDirectionButton.setImage(UIImage(named: "ConfirmIconDark"), for: UIControl.State.normal)
            self.directionButton.setImage(UIImage(named: "DirectionIconDark"), for: UIControl.State.normal)
            self.otherDirectionsButton.setImage(UIImage(named: "BusStopIconDark"), for: UIControl.State.normal)
            self.expandFiltersButton.setImage(UIImage(named: "FilterIconDark"), for: UIControl.State.normal)
            self.addNotificationButton.setImage(UIImage(named: "BellAddIconDark"), for: UIControl.State.normal)
            setFavoriteButtonImage(inverse: false)
            
            self.view.backgroundColor = UIColor.black.withAlphaComponent(DisplayConstants.mapAlphaValue)
        }
    }
    
    func darkImageAppend() -> String
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return ""
        case .dark:
            return "Dark"
        }
    }
    
    func locationFillAppend() -> String
    {
        if MapState.locationFilterEnabled
        {
            return "Fill"
        }
        else
        {
            return ""
        }
    }
    
    func favoriteFillAppend() -> String
    {
        if MapState.favoriteFilterEnabled
        {
            return "Fill"
        }
        else
        {
            return ""
        }
    }
    
    @objc func showPickerView()
    {
        NotificationCenter.default.post(name: NSNotification.Name("ShowRouteInfoPickerView"), object: nil)
    }
    
    @objc func hidePickerView()
    {
        NotificationCenter.default.post(name: NSNotification.Name("HideRouteInfoPickerView"), object: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "embedPanelTip"
        {
            let routeInfoPanelTipVC = segue.destination as! RouteInfoPanelTipViewController
            routeInfoPanelTipVC.mainMapViewController = mainMapViewController
        }
    }
        
    //MARK: - Picker View
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if MapState.routeInfoShowing == .vehicles
        {
            return routeInfoToChange.count + 1
        }
        
        return routeInfoToChange.count
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        if row > routeInfoToChange.count-1+(MapState.routeInfoShowing == .vehicles ? 1 : 0) { return NSAttributedString(string: "", attributes: [:]) }
        
        var title: String?
        
        switch MapState.routeInfoShowing
        {
        case .none:
            title = nil
        case .direction:
            title = (routeInfoToChange[row] as? Direction)?.title
        case .stop:
            title = (routeInfoToChange[row] as? Stop)?.title
        case .otherDirections:
            let routeTitle = (routeInfoToChange[row] as? Direction)?.route?.title ?? ""
            let directionName = (routeInfoToChange[row] as? Direction)?.name ?? ""
            
            title = routeTitle + " - " + directionName
        case .vehicles:
            if row == 0
            {
                title = "None"
            }
            else
            {
                if let vehiclePrediction = (routeInfoToChange[row-1] as? (vehicleID: String?, prediction: String))
                {
                    let predictionInt = Int(vehiclePrediction.prediction)
                    var predictionString = vehiclePrediction.prediction
                    if (predictionInt == 0)
                    {
                        predictionString = "Now"
                    }
                    else if (predictionInt == 1)
                    {
                        predictionString += " min"
                    }
                    else
                    {
                        predictionString += " mins"
                    }
                    
                    title = predictionString
                    if let vehicleID = vehiclePrediction.vehicleID
                    {
                        title! += " ID: " + vehicleID
                    }
                }
                else
                {
                    title = "?"
                }
            }
        }
        
        return NSAttributedString(string: title ?? "", attributes: [:])
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerSelectedRow()
        
        if MapState.locationFilterEnabled
        {
            MapState.locationFilterEnabled = false
        }
        
        for filterButton in filterButtons
        {
            if filterButton.imagePath == "CurrentLocation"
            {
                filterButton.filterIsEnabled = MapState.locationFilterEnabled
                filterButton.setFilterImage()
            }
        }
    }
    
    //MARK: - Data Reload
    
    @objc func reloadRouteData()
    {
        if MapState.showingPickerView
        {
            routeInfoToChange.removeAll()
            
            var rowToSelect = 0
            
            switch MapState.routeInfoShowing
            {
            case .none:
                mainMapViewController?.showPickerHelpInfoView()
            case .direction:
                routeInfoToChange = (MapState.routeInfoObject as? Route)?.directions?.array as? Array<Direction> ?? Array<Direction>()
                
                disableFilterButtons()
                
                confirmDirectionButton.isHidden = false
                confirmDirectionButton.isEnabled = true
                directionButton.isHidden = true
                directionButton.isEnabled = false
                
                otherDirectionsButton.isHidden = true
                otherDirectionsButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
                if (routeInfoToChange as! Array<Direction>).count < 1 { break }
                rowToSelect = (routeInfoToChange as! Array<Direction>).firstIndex(of: (routeInfoToChange as! Array<Direction>).filter({$0.tag == MapState.selectedDirectionTag}).first ?? (routeInfoToChange as! Array<Direction>)[0]) ?? 0
            case .stop:
                routeInfoToChange = (MapState.routeInfoObject as? Direction)?.stops?.array as? Array<Stop> ?? Array<Stop>()
                
                showFilterButtons()
                
                confirmDirectionButton.isHidden = true
                confirmDirectionButton.isEnabled = false
                directionButton.isHidden = false
                directionButton.isEnabled = true
                
                otherDirectionsButton.isHidden = false
                otherDirectionsButton.isEnabled = true
                
                addFavoriteButton.isHidden = false
                addFavoriteButton.isEnabled = true
//                addNotificationButton.isHidden = false
//                addNotificationButton.isEnabled = true
                
                if (routeInfoToChange as! Array<Stop>).count < 1 { break }
                rowToSelect = (routeInfoToChange as! Array<Stop>).firstIndex(of: (routeInfoToChange as! Array<Stop>).filter({$0.tag == MapState.selectedStopTag}).first ?? (routeInfoToChange as! Array<Stop>)[0]) ?? 0
            case .otherDirections:
                routeInfoToChange = MapState.routeInfoObject as? Array<Direction> ?? Array<Direction>()
                
                disableFilterButtons()
                
                confirmDirectionButton.isHidden = true
                confirmDirectionButton.isEnabled = false
                directionButton.isHidden = true
                directionButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
                if (routeInfoToChange as! Array<Direction>).count < 1 { break }
                rowToSelect = (routeInfoToChange as! Array<Direction>).firstIndex(of: (routeInfoToChange as! Array<Direction>).filter({$0.tag == MapState.selectedDirectionTag}).first ?? (routeInfoToChange as! Array<Direction>)[0]) ?? 0
            case .vehicles:
                routeInfoToChange = MapState.routeInfoObject as? Array<(vehicleID: String, prediction: String)> ?? Array<(vehicleID: String, prediction: String)>()
                
                disableFilterButtons()
                
                confirmDirectionButton.isHidden = true
                confirmDirectionButton.isEnabled = false
                directionButton.isHidden = true
                directionButton.isEnabled = false
                
                otherDirectionsButton.isHidden = true
                otherDirectionsButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
                var vehicleOn = 0
                for vehicle in routeInfoToChange as! Array<(vehicleID: String, prediction: String)>
                {
                    if vehicle.vehicleID == MapState.selectedVehicleID
                    {
                        rowToSelect = vehicleOn + 1
                        break
                    }
                    
                    vehicleOn += 1
                }
            }
            
            OperationQueue.main.addOperation {
                if MapState.favoriteFilterEnabled
                {
                    self.filterByFavorites()
                }
                else if MapState.locationFilterEnabled
                {
                    self.routeInfoPicker.reloadAllComponents()
                    
                    if let currentLocation = appDelegate.mainMapViewController?.mainMapView?.userLocation.location
                    {
                        self.sortStopsByCurrentLocation(location: currentLocation)
                    }
                }
                else
                {
                    self.routeInfoPicker.reloadAllComponents()
                    self.routeInfoPicker.selectRow(rowToSelect, inComponent: 0, animated: true)
                    
                    self.updateSelectedObjectTags()
                    
                    self.setFavoriteButtonImage(inverse: false)
                }
                
                if self.routeInfoToChange.count == 0
                {
                    self.addFavoriteButton.isHidden = true
                    self.addFavoriteButton.isEnabled = false
                    self.addNotificationButton.isHidden = true
                    self.addNotificationButton.isEnabled = false
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":true])
            }
        }
        else
        {
            //self.view.superview!.isHidden = true
        }
    }
    
    @IBAction func confirmDirectionButtonPressed(_ sender: Any) {
        if MapState.routeInfoShowing == .direction
        {
            switchRouteInfoDirectionToStop()
            reloadRouteData()
        }
    }
    
    @IBAction func directionButtonSingleTap()
    {
        if MapState.routeInfoShowing == .stop
        {
            let route = (MapState.routeInfoObject as? Direction)?.route
            
            if route?.directions?.count == 2
            {
                switchDirection(route: route!)
            }
            else
            {
                switchRouteInfoStopToDirection()
            }
            reloadRouteData()
        }
    }
    
    @IBAction func directionButtonLongPress()
    {
        if MapState.routeInfoShowing == .stop
        {
            switchRouteInfoStopToDirection()
            reloadRouteData()
        }
    }
    
    func switchRouteInfoDirectionToStop()
    {
        if routeInfoToChange.count == 0 { return }
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Direction
    }
    
    func switchRouteInfoStopToDirection()
    {
        MapState.routeInfoShowing = .direction
        MapState.routeInfoObject = (MapState.routeInfoObject as? Direction)?.route
    }
    
    func switchDirection(route: Route)
    {
        var directionArray = route.directions!.array as! [Direction]
        directionArray.remove(at: directionArray.firstIndex(of: (MapState.routeInfoObject as! Direction))!)
        MapState.routeInfoObject = directionArray[0]
        MapState.selectedDirectionTag = directionArray[0].tag
        
        if let selectedStop = MapState.getCurrentStop(), let stops = directionArray[0].stops?.array as? [Stop]
        {
            let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: stops, locationToTest: CLLocation(latitude: selectedStop.latitude, longitude: selectedStop.longitude))
            MapState.selectedStopTag = sortedStops[0].tag
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ReloadAnnotations"), object: nil)
    }
    
    func pickerSelectedRow()
    {
        updateSelectedObjectTags()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":false])
        setFavoriteButtonImage(inverse: false)
    }
    
    func updateSelectedObjectTags()
    {
        let row = routeInfoPicker.selectedRow(inComponent: 0)
        
        if routeInfoToChange.count > row || (MapState.routeInfoShowing == .vehicles && routeInfoToChange.count + 1 > row)
        {
            switch MapState.routeInfoShowing
            {
            case .direction:
                if let direction = routeInfoToChange[row] as? Direction
                {
                    MapState.selectedDirectionTag = direction.tag
                }
            case .stop:
                if let stop = routeInfoToChange[row] as? Stop
                {
                    MapState.selectedStopTag = stop.tag
                    
                    updateRecentStops()
                }
            case .otherDirections:
                if let direction = routeInfoToChange[row] as? Direction
                {
                    MapState.selectedDirectionTag = direction.tag
                }
            case .vehicles:
                if row == 0
                {
                    MapState.selectedVehicleID = nil
                }
                else if let vehicleID = (routeInfoToChange[row-1] as? (vehicleID: String, prediction: String))?.vehicleID
                {
                    MapState.selectedVehicleID = vehicleID
                }
            default:
                break
            }
        }
    }
    
    func updateRecentStops()
    {
        CoreDataStack.persistentContainer.performBackgroundTask { (backgroundMOC) in
            if let mapStateDirectionTag = MapState.selectedDirectionTag, let currentRecentStopUUID = MapState.currentRecentStopUUID, let currentRecentStopArray = CoreDataStack.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "uuid == %@", currentRecentStopUUID), moc: backgroundMOC) as? [RecentStop], currentRecentStopArray.count > 0
            {
                let currentRecentStop = currentRecentStopArray[0]
                
                if currentRecentStop.directionTag != nil && RouteDataManager.fetchDirection(directionTag: currentRecentStop.directionTag!)?.route?.tag == RouteDataManager.fetchDirection(directionTag: mapStateDirectionTag)?.route?.tag
                {
                    if self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC, uuidToNotMatch: currentRecentStop.uuid!)
                    {
                        backgroundMOC.delete(currentRecentStop)
                    }
                    else
                    {
                        currentRecentStop.directionTag = MapState.selectedDirectionTag
                        currentRecentStop.stopTag = MapState.selectedStopTag
                        currentRecentStop.timestamp = Date()
                    }
                }
                else
                {
                    if !self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC, uuidToNotMatch: currentRecentStop.uuid!)
                    {
                        self.insertNewRecentStop(backgroundMOC: backgroundMOC)
                    }
                }
            }
            else if MapState.selectedDirectionTag != nil && MapState.selectedStopTag != nil
            {
                if !self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC)
                {
                    self.insertNewRecentStop(backgroundMOC: backgroundMOC)
                }
            }
            
            if var oldRecentStops = CoreDataStack.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: backgroundMOC, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]) as? [RecentStop], oldRecentStops.count > 20
            {
                oldRecentStops = Array<RecentStop>(oldRecentStops[20...oldRecentStops.count-1])
                for oldStop in oldRecentStops
                {
                    backgroundMOC.delete(oldStop)
                }
            }
            
            try? backgroundMOC.save()
        }
    }
    
    func insertNewRecentStop(backgroundMOC: NSManagedObjectContext)
    {
        let recentStop = NSEntityDescription.insertNewObject(forEntityName: "RecentStop", into: backgroundMOC) as! RecentStop
        recentStop.directionTag = MapState.selectedDirectionTag
        recentStop.stopTag = MapState.selectedStopTag
        recentStop.timestamp = Date()
        recentStop.uuid = UUID().uuidString
        MapState.currentRecentStopUUID = recentStop.uuid
    }
    
    func checkForDuplicateRecentStop(backgroundMOC: NSManagedObjectContext, uuidToNotMatch: String? = nil) -> Bool
    {
        var predicateFormat = "directionTag == %@ AND stopTag == %@"
        if uuidToNotMatch != nil
        {
            predicateFormat += " AND uuid != %@"
        }
        if MapState.selectedDirectionTag != nil && MapState.selectedStopTag != nil, let duplicateRecentStopArray = CoreDataStack.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: predicateFormat, MapState.selectedDirectionTag!, MapState.selectedStopTag!, uuidToNotMatch ?? ""), moc: backgroundMOC) as? [RecentStop]
        {
            if duplicateRecentStopArray.count > 0
            {
                let recentStopToBringToFront = duplicateRecentStopArray[0]
                recentStopToBringToFront.timestamp = Date()
                MapState.currentRecentStopUUID = recentStopToBringToFront.uuid
                
                //backgroundMOC.delete(currentRecentStop)
                
                return true
            }
            
            return false
        }
        
        return false
    }
    
    @objc func selectCurrentStop()
    {
        if !MapState.favoriteFilterEnabled
        {
            if MapState.routeInfoShowing == .stop, let stops = routeInfoToChange as? Array<Stop>
            {
                self.routeInfoPicker.selectRow(stops.firstIndex(of: stops.first(where: {$0.tag == MapState.selectedStopTag})!) ?? 0, inComponent: 0, animated: true)
                
                MapState.locationFilterEnabled = false
                for filterButton in filterButtons
                {
                    if filterButton.imagePath == "CurrentLocation"
                    {
                        filterButton.filterIsEnabled = MapState.locationFilterEnabled
                        filterButton.setFilterImage()
                    }
                }
                
                pickerSelectedRow()
            }
        }
    }
    
    //MARK: - Filters
    
    var filterButtons = [FilterButton]()
    
    func showFilterButtons()
    {
        if filtersExpanded
        {
            filterButtons.forEach { (filterButton) in
                filterButton.enableButton()
            }
        }
        else
        {
            expandFiltersButton.isHidden = false
            expandFiltersButton.isEnabled = true
        }
    }
    
    func disableFilterButtons()
    {
        filtersExpanded = false
        
        expandFiltersButton.isHidden = true
        expandFiltersButton.isEnabled = false
        
        filterButtons.forEach { (filterButton) in
            filterButton.disableButton()
        }
        
        disableFilters()
    }
    
    @IBAction func expandFilters()
    {
        filtersExpanded = true
        
        expandFiltersButton.isHidden = true
        expandFiltersButton.isEnabled = false
        
        showFilterButtons()
                
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -8
        }
        
        self.routeInfoPickerContainer.layoutSubviews()
        
        var filterButtonNumber: CGFloat = 0
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -1*(((filterButton.frame.size.height)*filterButtonNumber) + (8*(filterButtonNumber+1)))
            filterButtonNumber += 1
        }
        
        UIView.animate(withDuration: 0.5) {
            self.routeInfoPickerContainer.layoutSubviews()
        }
    }
    
    @objc func collapseFilters()
    {
        filtersExpanded = false
        
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -8
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.routeInfoPickerContainer.layoutSubviews()
        }) { (bool) in
            for filterButton in self.filterButtons
            {
                filterButton.disableButton()
            }
            
            if MapState.routeInfoShowing == .stop
            {
                self.expandFiltersButton.isHidden = false
                self.expandFiltersButton.isEnabled = true
            }
        }
    }
    
    @objc func disableFilters()
    {
        MapState.favoriteFilterEnabled = false
        MapState.locationFilterEnabled = false
        
        for filterButton in filterButtons
        {
            filterButton.filterIsEnabled = false
            filterButton.setFilterImage()
        }
    }
    
    @objc func enableFilters()
    {
        expandFilters()
        
        MapState.favoriteFilterEnabled = true
        MapState.locationFilterEnabled = true
        
        for filterButton in filterButtons
        {
            filterButton.filterIsEnabled = true
            filterButton.setFilterImage()
        }
    }
    
    @IBAction func favoriteFilterButtonPressed(_ sender: Any) {
        MapState.favoriteFilterEnabled = !MapState.favoriteFilterEnabled
        
        if MapState.favoriteFilterEnabled
        {
            filterByFavorites()
        }
        else
        {
            reloadRouteData()
        }
    }
    
    @objc func toggleFavoriteForSelectedStop()
    {
        if MapState.routeInfoShowing == .stop
        {
            if let selectedStop = MapState.getCurrentStop(), let selectedDirection = MapState.getCurrentDirection()
            {
                let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.tag!, stopTag: selectedStop.tag)
                if favoriteStopCallback.count > 0
                {
                    CoreDataStack.persistentContainer.viewContext.delete(favoriteStopCallback[0])
                    
                    NotificationCenter.default.addObserver(self, selector: #selector(didSaveFavoriteStop), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                }
                else
                {
                    let newFavoriteStop = FavoriteStop(context: CoreDataStack.persistentContainer.viewContext)
                    newFavoriteStop.directionTag = selectedDirection.tag
                    newFavoriteStop.stopTag = selectedStop.tag
                    newFavoriteStop.uuid = UUID().uuidString
                    
                    NotificationCenter.default.addObserver(self, selector: #selector(didSaveFavoriteStop), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                }
                
                CoreDataStack.saveContext()
            }
        }
    }
    
    @objc func didSaveFavoriteStop(notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    func filterByFavorites()
    {
        if let selectedDirection = MapState.getCurrentDirection()
        {
            var favoriteStops = Array<Stop>()
            let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.tag!)
            for favoriteStop in favoriteStopCallback
            {
                guard let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!) else { return }
                let stopDirections = stop.direction?.map { (direction) -> String in
                    return (direction as? Direction)?.tag ?? ""
                } ?? []
                
                if !stopDirections.contains(selectedDirection.tag!) { continue }
                
                favoriteStops.append(stop)
            }
            
            if let directionStopArray = selectedDirection.stops?.array as? [Stop]
            {
                let directionStopTagArray = directionStopArray.map({ (stop) -> String in
                    return stop.tag!
                })
                favoriteStops.sort { (stop1, stop2) -> Bool in
                    return (directionStopTagArray.firstIndex(of: stop1.tag!) ?? 0) < (directionStopTagArray.firstIndex(of: stop2.tag!) ?? 0)
                }
            }
            
            routeInfoToChange = favoriteStops
            
            OperationQueue.main.addOperation {
                self.routeInfoPicker.reloadAllComponents()
                
                if MapState.locationFilterEnabled
                {
                    if let currentLocation = appDelegate.mainMapViewController?.mainMapView?.userLocation.location
                    {
                        self.sortStopsByCurrentLocation(location: currentLocation)
                    }
                }
                else
                {
                    self.routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
                    
                    self.pickerSelectedRow()
                }
                
                if self.routeInfoToChange.count == 0
                {
                    self.addFavoriteButton.isHidden = true
                    self.addFavoriteButton.isEnabled = false
                }
            }
        }
    }
    
    @IBAction func locationFilterButtonPressed(_ sender: Any) {
        MapState.locationFilterEnabled = !MapState.locationFilterEnabled
        
        if MapState.locationFilterEnabled
        {
            if let currentLocation = appDelegate.mainMapViewController?.mainMapView?.userLocation.location
            {
                sortStopsByCurrentLocation(location: currentLocation)
            }
        }
        else
        {
            reloadRouteData()
        }
    }
    
    func sortStopsByCurrentLocation(location: CLLocation)
    {
        if let routeStops = routeInfoToChange as? Array<Stop>
        {
            let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: routeStops, locationToTest: location)
            
            let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
            
            OperationQueue.main.addOperation {
                switch locationSortType
                {
                case .fullSort:
                    self.routeInfoToChange = sortedStops
                    
                    self.routeInfoPicker.reloadAllComponents()
                    self.routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
                case .selectClosest:
                    if sortedStops.count > 0
                    {
                        self.routeInfoPicker.selectRow(routeStops.firstIndex(of: sortedStops[0]) ?? 0, inComponent: 0, animated: true)
                    }
                }
                
                self.pickerSelectedRow()
            }
        }
    }
    
    //MARK: - Other Directions
    
    @IBAction func otherDirectionsButtonPressed(_ sender: Any)
    {
        if let selectedStop = MapState.getCurrentStop()
        {
            MapState.routeInfoObject = selectedStop.direction?.allObjects
            appDelegate.mainMapViewController?.performSegue(withIdentifier: "showOtherDirectionsTableView", sender: self)
        }
    }
    
    @IBAction func otherDirectionsButtonDoubleTapped(_ sender: Any)
    {
        appDelegate.mainMapViewController?.openNearbyStopViewFromSelectedStop(sender)
    }
    
    //MARK: - Add Favorite / Notification
    
    @IBAction func addFavoriteButtonPressed(_ sender: Any) {
        setFavoriteButtonImage(inverse: true)
        
        toggleFavoriteForSelectedStop()
    }
    
    func setFavoriteButtonImage(inverse: Bool)
    {
        if MapState.selectedStopTag != nil
        {
            if let stop = MapState.getCurrentStop(), let direction = MapState.getCurrentDirection()
            {
                var stopIsFavorite = RouteDataManager.favoriteStopExists(stopTag: stop.tag!, directionTag: direction.tag!)
                if inverse
                {
                    stopIsFavorite = !stopIsFavorite
                }
                
                if stopIsFavorite
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddFillIcon\(darkImageAppend())"), for: UIControl.State.normal)
                }
                else
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddIcon\(darkImageAppend())"), for: UIControl.State.normal)
                }
            }
        }
    }
    
    @IBAction func addNotificationButtonPressed(_ sender: Any) {
        CoreDataStack.persistentContainer.performBackgroundTask { moc in            
            let newNotification = StopNotification(context: moc)
            newNotification.daysOfWeek = try? JSONSerialization.data(withJSONObject: [true, true, true, true, true, true, true], options: JSONSerialization.WritingOptions.sortedKeys)
            newNotification.directionTag = MapState.selectedDirectionTag
            newNotification.stopTag = MapState.selectedStopTag
            newNotification.stopTitle = MapState.getCurrentStop()?.title
            newNotification.routeTag = MapState.getCurrentDirection()?.route?.tag
            newNotification.hour = 12
            newNotification.minute = 0
            newNotification.uuid = UUID().uuidString
            newNotification.deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as? String
            
            try? moc.save()
            
            appDelegate.mainMapViewController?.newStopNotificationID = newNotification.objectID
            OperationQueue.main.addOperation {
                appDelegate.mainMapViewController?.performSegue(withIdentifier: "openNewNotificationEditor", sender: self)
            }
        }
    }
}
