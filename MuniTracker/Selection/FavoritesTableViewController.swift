//
//  FavoritesTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 7/14/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension UIColor
{
    convenience init(hexString: String)
    {
        let redIndex = hexString.startIndex
        let greenIndex = hexString.index(hexString.startIndex, offsetBy: 2)
        let blueIndex = hexString.index(hexString.startIndex, offsetBy: 4)
        
        let redColor = UIColor.convertHexStringToInt(hex: String(hexString[redIndex]) + String(hexString[hexString.index(after: redIndex)]))
        let greenColor = UIColor.convertHexStringToInt(hex: String(hexString[greenIndex]) + String(hexString[hexString.index(after: greenIndex)]))
        let blueColor = UIColor.convertHexStringToInt(hex: String(hexString[blueIndex]) + String(hexString[hexString.index(after: blueIndex)]))
        
        self.init(red: CGFloat(redColor)/255, green: CGFloat(greenColor)/255, blue: CGFloat(blueColor)/255, alpha: 1)
    }
    
    class func convertHexStringToInt(hex: String) -> Int
    {
        let hexDigit1 = hexToInt(hex: hex[hex.startIndex])
        let hexDigit2 = hexToInt(hex: hex[hex.index(after: hex.startIndex)])
        
        return (hexDigit1*16)+hexDigit2
    }
    
    class func hexToInt(hex: Character) -> Int
    {
        let lowerHex = String(hex).lowercased()
        switch lowerHex
        {
        case "a":
            return 10
        case "b":
            return 11
        case "c":
            return 12
        case "d":
            return 13
        case "e":
            return 14
        case "f":
            return 15
        default:
            return Int(lowerHex) ?? 0
        }
    }
}

class FavoritesTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var favoriteStopObjects: Array<FavoriteStop>?
    var loadedPredictions = Array<Bool>()
    var favoriteStopSet: Array<Stop>?
    var favoriteRouteSet: Array<Route>?
    var favoriteStopGroupSet: Array<NSManagedObject>?
    var favoriteStopsToAddToGroup: Array<String>?
    var refreshControl: UIRefreshControl?
    @IBOutlet weak var organizeSegmentControl: UISegmentedControl!
    @IBOutlet weak var favoriteStopsTableView: UITableView!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    
    override func viewDidLoad() {        
        if FavoriteState.favoritesOrganizeType != .group && FavoriteState.favoritesOrganizeType != .addingToGroup
        {
            reloadTableView()
            NotificationCenter.default.addObserver(self, selector: #selector(finishedCloudFetch(_:)), name: NSNotification.Name("FinishedFetchingFromCloud"), object: nil)
            CloudManager.fetchChangesFromCloud()
        }
        
        organizeSegmentControl.selectedSegmentIndex = FavoriteState.favoritesOrganizeType.rawValue
        
        setupThemeElements()
        setupOrganizeTypeStuff()
    }
    
    @objc func finishedCloudFetch(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        reloadTableView()
    }
    
    func reloadTableView()
    {
        fetchFavoriteStops()
        sortFavoriteStops()
        
        switch FavoriteState.favoritesOrganizeType
        {
        case .list, .addingToGroup:
            break
        case .stop:
            fetchStopSet()
            sortStopSet()
        case .route:
            fetchRouteSet()
            sortRouteSet()
        case .group:
            fetchGroupSet()
            sortGroupSet()
        }
        
        favoriteStopsTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
        
        setupOrganizeTypeStuff()
    }
    
    func setupOrganizeTypeStuff()
    {
        if FavoriteState.favoritesOrganizeType == .group
        {
            reloadTableView()
            self.mainNavigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToGroupButtonPressed)), animated: false)
            if FavoriteState.selectedGroupUUID != "0", let currentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup
            {
                mainNavigationItem.title = currentGroup.groupName
            }
            else
            {
                mainNavigationItem.title = "Groups"
            }
        }
        else if FavoriteState.favoritesOrganizeType == .addingToGroup
        {
            favoriteStopsToAddToGroup = Array<String>()
            reloadTableView()
            self.mainNavigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAddingToGroup)), animated: false)
            
            organizeSegmentControl.selectedSegmentIndex = FavoriteState.FavoritesOrganizeType.list.rawValue
            organizeSegmentControl.isEnabled = false
            
            if let currentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup
            {
                mainNavigationItem.title = "Add to " + (currentGroup.groupName ?? "")
            }
        }
        else
        {
            mainNavigationItem.title = "Favorites"
            mainNavigationItem.setRightBarButton(nil, animated: false)
        }
        
        if FavoriteState.favoritesOrganizeType == .addingToGroup
        {
            favoriteStopsTableView.allowsMultipleSelection = true
        }
        
        refreshControl = UIRefreshControl()
        favoriteStopsTableView.refreshControl = refreshControl
        refreshControl?.addTarget(self, action: #selector(reloadGroupPredictions), for: UIControl.Event.valueChanged)
        refreshControl?.tintColor = UIColor.black
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        //let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = offWhite
            self.mainNavigationBar.barTintColor = offWhite
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
        case .dark:
            self.view.backgroundColor = black
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        }
    }
    
    func fetchFavoriteStops()
    {
        if let favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: CoreDataStack.persistentContainer.viewContext) as? [FavoriteStop]
        {
            favoriteStopObjects = favoriteStops
            
            loadedPredictions = Array<Bool>()
            for _ in favoriteStops
            {
                loadedPredictions.append(false)
            }
        }
    }
    
    func sortFavoriteStops()
    {
        if var favoriteStops = favoriteStopObjects
        {
            favoriteStops.sort(by: {
                if let direction1 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $0.directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction, let direction2 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $1.directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
                {
                    return direction1.route!.routeTag!.compare(direction2.route!.routeTag!, options: .numeric) == .orderedAscending
                }
                else
                {
                    return true
                }
            })
            
            favoriteStopObjects = favoriteStops
        }
    }
    
    func fetchStopSet()
    {
        favoriteStopSet = Array<Stop>()
        
        for favoriteStop in favoriteStopObjects!
        {
            if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!)
            {
                if favoriteStopSet?.firstIndex(of: stop) == nil
                {
                    favoriteStopSet?.append(stop)
                }
            }
        }
    }
    
    func sortStopSet()
    {
        if var stopSet = favoriteStopSet
        {
            if let location = appDelegate.mainMapViewController?.mainMapView.userLocation.location
            {
                stopSet = RouteDataManager.sortStopsByDistanceFromLocation(stops: stopSet, locationToTest: location)
            }
            else
            {
                stopSet.sort {
                    return $0.stopTitle!.compare($1.stopTitle!, options: .numeric) == .orderedAscending
                }
            }
            
            favoriteStopSet = stopSet
        }
    }
    
    func fetchRouteSet()
    {
        favoriteRouteSet = Array<Route>()
        
        for favoriteStop in favoriteStopObjects!
        {
            if let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
            {
                if favoriteRouteSet?.firstIndex(of: direction.route!) == nil
                {
                    favoriteRouteSet?.append(direction.route!)
                }
            }
        }
    }
    
    func sortRouteSet()
    {
        if var routeSet = favoriteRouteSet
        {
            routeSet.sort {
                return $0.routeTag!.compare($1.routeTag!, options: .numeric) == .orderedAscending
            }
            
            favoriteRouteSet = routeSet
        }
    }
    
    func getFavoritedStopsFromRoute(route: Route) -> (stops: Array<Stop>, favoriteStops: Array<FavoriteStop>)?
    {
        if let favoriteStops = favoriteStopObjects
        {
            var favoriteRouteStops = Array<Stop>()
            var favoriteStopObjects = Array<FavoriteStop>()
            for favoriteStop in favoriteStops
            {
                if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
                {
                    if favoriteRouteStops.firstIndex(of: stop) == nil && direction.route == route
                    {
                        favoriteRouteStops.append(stop)
                        favoriteStopObjects.append(favoriteStop)
                    }
                }
            }
            
            return (favoriteRouteStops, favoriteStopObjects)
        }
        
        return nil
    }
    
    func fetchGroupSet()
    {
        favoriteStopObjects = []
        favoriteStopGroupSet = []
        
        if let currentGroup = RouteDataManager.fetchOrCreateObject(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext).object as? FavoriteStopGroup, let childObjects = currentGroup.childGroups?.allObjects as? [FavoriteStopGroup], let favoriteStopUUIDs = CoreDataStack.decodeArrayFromJSON(object: currentGroup, field: "favoriteStopUUIDs") as? [String]
        {
            favoriteStopGroupSet = childObjects
            for favoriteStopUUID in favoriteStopUUIDs
            {
                if let favoriteStop = RouteDataManager.fetchOrCreateObject(type: "FavoriteStop", predicate: NSPredicate(format: "uuid == %@", favoriteStopUUID), moc: CoreDataStack.persistentContainer.viewContext).object as? FavoriteStop
                {
                    favoriteStopGroupSet?.append(favoriteStop)
                }
            }
        }
    }
    
    func sortGroupSet()
    {
        if var favoriteStopGroups = favoriteStopGroupSet
        {
            favoriteStopGroups.sort {
                if $0 is FavoriteStopGroup && $1 is FavoriteStopGroup
                {
                    return ($0 as! FavoriteStopGroup).openCount > ($1 as! FavoriteStopGroup).openCount
                }
                else if $0 is FavoriteStopGroup && !($1 is FavoriteStopGroup)
                {
                    return true
                }
                else if !($0 is FavoriteStopGroup) && $1 is FavoriteStopGroup
                {
                    return false
                }
                else if $0 is FavoriteStop && $1 is FavoriteStop, let direction1 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", ($0 as! FavoriteStop).directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction, let direction2 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", ($1 as! FavoriteStop).directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction
                {
                    return direction1.route!.routeTag!.compare(direction2.route!.routeTag!, options: .numeric) == .orderedAscending
                }
                
                return false
            }
        }
    }
    
    func fetchFavoritesPredictionTimes()
    {
        if let favoriteStops = favoriteStopObjects
        {
            for favoriteStop in favoriteStops
            {
                let index = favoriteStops.firstIndex(of: favoriteStop)!
                let predictionTimesReturnUUID = UUID().uuidString + ";" + String(index)
                NotificationCenter.default.addObserver(self, selector: #selector(receiveFavoritesPrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
                if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
                {
                    RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
                }
                
            }
        }
    }
    
    @objc func receiveFavoritesPrediction(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        if let predictions = notification.userInfo!["predictions"] as? [String], FavoriteState.favoritesOrganizeType == .list || FavoriteState.favoritesOrganizeType == .group
        {
            OperationQueue.main.addOperation {
                let predictionsString = MapState.formatPredictions(predictions: predictions).predictionsString
                let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
                
                if let favoritesPredictionLabel = self.favoriteStopsTableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                {
                    self.loadedPredictions[indexRow] = true
                    favoritesPredictionLabel.text = predictionsString
                }
                
                if self.refreshingStopsLeft > 0
                {
                    self.refreshingStopsLeft -= 1
                    if self.refreshingStopsLeft == 0
                    {
                        self.refreshControl?.endRefreshing()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
        var favoriteStop: FavoriteStop?
        if FavoriteState.favoritesOrganizeType == .list && !loadedPredictions[indexPath.row]
        {
            favoriteStop = favoriteStopObjects![indexPath.row]
        }
        
        if FavoriteState.favoritesOrganizeType == .group && favoriteStopGroupSet![indexPath.row] is FavoriteStop
        {
            favoriteStop = favoriteStopGroupSet![indexPath.row] as? FavoriteStop
        }
        
        if favoriteStop != nil
        {
            fetchPredictionTime(favoriteStop: favoriteStop!, predictionTimesReturnUUID: predictionTimesReturnUUID)
        }
    }
    
    func fetchPredictionTime(favoriteStop: FavoriteStop, predictionTimesReturnUUID: String)
    {
        NotificationCenter.default.addObserver(self, selector: #selector(receiveFavoritesPrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
        {
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch FavoriteState.favoritesOrganizeType
        {
        case .list, .addingToGroup:
            return favoriteStopObjects?.count ?? 0
        case .stop:
            return favoriteStopSet?.count ?? 0
        case .route:
            return favoriteRouteSet?.count ?? 0
        case .group:
            return favoriteStopGroupSet?.count ?? 0
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var textColor = UIColor.black
        
        switch FavoriteState.favoritesOrganizeType
        {
        case .list, .addingToGroup:
            let favoriteStopObject = favoriteStopObjects![indexPath.row]
            
            return createFavoriteStopCell(favoriteStopObject: favoriteStopObject, tableView: tableView)
        case .stop:
            let favoriteStopCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteStopCell")!
            let stopObject = favoriteStopSet![indexPath.row]
            
            (favoriteStopCell.viewWithTag(600) as! UILabel).text = stopObject.stopTitle
            (favoriteStopCell.viewWithTag(601) as! UILabel).text = (stopObject.direction?.allObjects.first as? Direction)?.directionName
            
            textColor = UIColor.white
            
            if indexPath.row % 2 == 0
            {
                favoriteStopCell.backgroundColor = UIColor(red: 0, green: 0.5, blue: 0.8, alpha: 1)
            }
            else
            {
                favoriteStopCell.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0.7, alpha: 1)
            }
            
            (favoriteStopCell.viewWithTag(600) as! UILabel).textColor = textColor
            (favoriteStopCell.viewWithTag(601) as! UILabel).textColor = textColor
            
            return favoriteStopCell
        case .route:
            let favoriteRouteCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteRouteCell")!
            let routeObject = favoriteRouteSet![indexPath.row]
            
            if let routeColor = routeObject.routeColor, let routeOppositeColor = routeObject.routeOppositeColor
            {
                favoriteRouteCell.backgroundColor = UIColor(hexString: routeColor)
                textColor = UIColor(hexString: routeOppositeColor)
            }
            
            (favoriteRouteCell.viewWithTag(600) as! UILabel).text = routeObject.routeTag
            let favoritedStopsFromRoute = getFavoritedStopsFromRoute(route: routeObject)?.stops
            if favoritedStopsFromRoute?.count == 1
            {
                (favoriteRouteCell.viewWithTag(601) as! UILabel).text = String(favoritedStopsFromRoute?.count ?? 0) + " favorite stop"
            }
            else
            {
                (favoriteRouteCell.viewWithTag(601) as! UILabel).text = String(favoritedStopsFromRoute?.count ?? 0) + " favorite stops"
            }
            (favoriteRouteCell.viewWithTag(602) as! UILabel).text = ""
            (favoriteRouteCell.viewWithTag(603) as! UILabel).text = ""
            
            (favoriteRouteCell.viewWithTag(600) as! UILabel).textColor = textColor
            (favoriteRouteCell.viewWithTag(601) as! UILabel).textColor = textColor
            (favoriteRouteCell.viewWithTag(602) as! UILabel).textColor = textColor
            (favoriteRouteCell.viewWithTag(603) as! UILabel).textColor = textColor
            
            return favoriteRouteCell
        case .group:
            let groupObject = favoriteStopGroupSet![indexPath.row]
            
            if groupObject is FavoriteStopGroup
            {
                let groupCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteStopGroupCell")!
                
                let favoriteStopCount = getFavoriteStopCount(group: groupObject as! FavoriteStopGroup)
                let childGroupCount = countChildGroups(group: groupObject as! FavoriteStopGroup)
                
                (groupCell.viewWithTag(601) as! UILabel).text = String(favoriteStopCount) + " favorite stop" + (favoriteStopCount != 1 ? "s" : "") + ", " + String(childGroupCount) + " child group" + (childGroupCount != 1 ? "s" : "")
                
                (groupCell.viewWithTag(600) as! UILabel).text = (groupObject as! FavoriteStopGroup).groupName
                
                return groupCell
            }
            else if groupObject is FavoriteStop
            {
                return createFavoriteStopCell(favoriteStopObject: groupObject as! FavoriteStop, tableView: tableView)
            }
            
            return tableView.dequeueReusableCell(withIdentifier: "FavoriteStopGroupCell")!
        }
    }
    
    func createFavoriteStopCell(favoriteStopObject: FavoriteStop, tableView: UITableView) -> UITableViewCell
    {
        var textColor = UIColor.black
        let favoriteRouteCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteRouteCell")!

        if let direction = RouteDataManager.fetchDirection(directionTag: favoriteStopObject.directionTag!)
        {
            if let routeColor = direction.route?.routeColor, let routeOppositeColor = direction.route?.routeOppositeColor
            {
                favoriteRouteCell.backgroundColor = UIColor(hexString: routeColor)
                
                textColor = UIColor(hexString: routeOppositeColor)
            }
            
            (favoriteRouteCell.viewWithTag(601) as! UILabel).text = direction.directionTitle
            (favoriteRouteCell.viewWithTag(600) as! UILabel).text = direction.route?.routeTag
        }
        
        if let stop = RouteDataManager.fetchStop(stopTag: favoriteStopObject.stopTag!)
        {
            (favoriteRouteCell.viewWithTag(602) as! UILabel).text = stop.stopTitle
        }
        
        (favoriteRouteCell.viewWithTag(600) as! UILabel).textColor = textColor
        (favoriteRouteCell.viewWithTag(601) as! UILabel).textColor = textColor
        (favoriteRouteCell.viewWithTag(602) as! UILabel).textColor = textColor
        (favoriteRouteCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        return favoriteRouteCell
    }
    
    func countChildGroups(group: FavoriteStopGroup) -> Int
    {
        let childGroups = group.childGroups?.allObjects as? [FavoriteStopGroup] ?? []
        var childGroupCount = childGroups.count
        for childGroup in childGroups
        {
            childGroupCount += countChildGroups(group: childGroup)
        }
        
        return childGroupCount
    }
    
    func getFavoriteStopCount(group: FavoriteStopGroup) -> Int
    {
        var favoriteStopCount = (try? JSONSerialization.jsonObject(with: group.favoriteStopUUIDs!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String] ?? [])?.count ?? 0
        let childGroups = group.childGroups?.allObjects as? [FavoriteStopGroup] ?? []
        for childGroup in childGroups
        {
            favoriteStopCount += getFavoriteStopCount(group: childGroup)
        }
        
        return favoriteStopCount
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if FavoriteState.favoritesOrganizeType == .group
        {
            let selectedObject = favoriteStopGroupSet![indexPath.row]
            if selectedObject is FavoriteStopGroup
            {
                openFavoriteGroup(groupObject: selectedObject as! FavoriteStopGroup)
            }
            else if selectedObject is FavoriteStop
            {
                openFavoriteStop(favoriteStop: selectedObject as! FavoriteStop)
            }
        }
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch FavoriteState.favoritesOrganizeType
        {
        case .list:
            let favoriteStop = favoriteStopObjects![indexPath.row]
            
            openFavoriteStop(favoriteStop: favoriteStop)
        case .stop:
            let stopObject = favoriteStopSet![indexPath.row]
            
            MapState.selectedStopTag = stopObject.stopTag
            MapState.routeInfoObject = stopObject.direction?.allObjects
            
            self.performSegue(withIdentifier: "showDirectionStopTableView", sender: self)
        case .route:
            let routeObject = favoriteRouteSet![indexPath.row]
            
            if let favoriteRouteStops = getFavoritedStopsFromRoute(route: routeObject)?.stops
            {
                if favoriteRouteStops.count > 0
                {
                    MapState.routeInfoObject = favoriteRouteStops[0].direction?.allObjects.filter({ ($0 as? Direction)?.route?.routeTag == routeObject.routeTag })[0]
                    MapState.routeInfoShowing = .stop
                    MapState.selectedDirectionTag = (MapState.routeInfoObject as? Direction)?.directionTag
                    self.performSegue(withIdentifier: "UnwindFromFavoritesViewWithSelectedRoute", sender: self)
                }
            }
        case .group:
            break
        case .addingToGroup:
            let selectedObject = favoriteStopObjects![indexPath.row]
            favoriteStopsToAddToGroup?.append(selectedObject.uuid ?? "")
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch FavoriteState.favoritesOrganizeType
        {
        case .addingToGroup:
            let selectedObject = favoriteStopObjects![indexPath.row]
            if let index = favoriteStopsToAddToGroup?.firstIndex(of: selectedObject.uuid ?? "")
            {
                favoriteStopsToAddToGroup?.remove(at: index)
            }
        default:
            break
        }
    }
    
    func openFavoriteGroup(groupObject: FavoriteStopGroup)
    {
        groupObject.openCount += 1
        CoreDataStack.saveContext()
        FavoriteState.selectedGroupUUID = groupObject.uuid
        self.performSegue(withIdentifier: "openFavoriteStopGroup", sender: self)
    }
    
    func openFavoriteStop(favoriteStop: FavoriteStop)
    {
        MapState.selectedDirectionTag = favoriteStop.directionTag
        MapState.selectedStopTag = favoriteStop.stopTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = MapState.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedFavoriteUnwind", sender: self)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if FavoriteState.favoritesOrganizeType == .group
        {
            let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
                if let groupObject = self.favoriteStopGroupSet?[indexPath.row]
                {
                    if groupObject is FavoriteStopGroup
                    {
                        self.deleteFavoriteGroupChildren(groupObject: groupObject as! FavoriteStopGroup)
                        CoreDataStack.persistentContainer.viewContext.delete(groupObject)
                    }
                    else if groupObject is FavoriteStop, let currentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup, var favoriteStopUUIDs = try? JSONSerialization.jsonObject(with: currentGroup.favoriteStopUUIDs!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String], let favoriteStopIndex = favoriteStopUUIDs.firstIndex(of: (groupObject as! FavoriteStop).uuid!)
                    {
                        favoriteStopUUIDs.remove(at: favoriteStopIndex)
                        currentGroup.favoriteStopUUIDs = try? JSONSerialization.data(withJSONObject: favoriteStopUUIDs, options: JSONSerialization.WritingOptions.prettyPrinted)
                    }
                    
                    self.favoriteStopGroupSet?.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    
                    CoreDataStack.saveContext()
                }
            }
            
            return [delete]
        }
        
        return nil
    }
    
    func deleteFavoriteGroupChildren(groupObject: FavoriteStopGroup)
    {
        for childGroup in (groupObject.childGroups?.allObjects as! [FavoriteStopGroup])
        {
            CoreDataStack.persistentContainer.viewContext.delete(childGroup)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDirectionStopTableView", let directionStopViewController = segue.destination as? DirectionsTableViewController
        {
            directionStopViewController.unwindSegueID = "UnwindFromDirectionStop"
        }
        else if segue.identifier == "openFavoriteStopGroup"
        {
            
        }
        
        if segue.identifier == "SelectedFavoriteUnwind" || segue.identifier == "showDirectionStopTableView" || segue.identifier == "UnwindFromFavoritesViewWithSelectedRoute"
        {
            FavoriteState.selectedGroupUUID = "0"
        }
        
        if segue.identifier == "UnwindFromFavoriteGroupView" && FavoriteState.favoritesOrganizeType == .addingToGroup
        {
            FavoriteState.favoritesOrganizeType = .group
        }
    }
    
    @IBAction func listStopSegmentPressed(_ sender: Any) {
        let segmentControl = sender as! UISegmentedControl
        
        FavoriteState.favoritesOrganizeType = FavoriteState.FavoritesOrganizeType(rawValue: segmentControl.selectedSegmentIndex) ?? .list
        
        if FavoriteState.favoritesOrganizeType == .group
        {
            self.mainNavigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToGroupButtonPressed)), animated: true)
        }
        else
        {
            self.mainNavigationItem.setRightBarButton(nil, animated: true)
        }
        
        reloadTableView()
    }
    
    @objc func addToGroupButtonPressed()
    {
        let alertViewController = UIAlertController(title: "Add \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")", message: nil, preferredStyle: .actionSheet)
        alertViewController.addAction(UIAlertAction(title: "Add \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")", style: .default, handler: { (action) in
            self.displayAddGroupAlert()
        }))
        alertViewController.addAction(UIAlertAction(title: "Add To \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")", style: .default, handler: { (action) in
            FavoriteState.favoritesOrganizeType = .addingToGroup
            self.performSegue(withIdentifier: "openFavoriteStopGroup", sender: self)
        }))
        alertViewController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            
        }))
        
        self.present(alertViewController, animated: true, completion: nil)
    }
    
    var refreshingStopsLeft = 0
    
    @objc func reloadGroupPredictions()
    {
        for object in favoriteStopGroupSet!
        {
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(favoriteStopGroupSet!.firstIndex(of: object) ?? 0)
            if object is FavoriteStop
            {
                refreshingStopsLeft += 1
                fetchPredictionTime(favoriteStop: object as! FavoriteStop, predictionTimesReturnUUID: predictionTimesReturnUUID)
            }
        }
        
        if refreshingStopsLeft == 0
        {
            self.refreshControl?.endRefreshing()
        }
    }
    
    func displayAddGroupAlert()
    {
        let newGroupAlert = UIAlertController(title: "New \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")", message: nil, preferredStyle: .alert)
        newGroupAlert.addTextField { (textField) in
            textField.placeholder = "New \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")"
        }
        newGroupAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            
        }))
        newGroupAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            let groupTitle = newGroupAlert.textFields![0].text ?? "New \(FavoriteState.selectedGroupUUID ?? "0" == "0" ? "Group" : "Group")"
            self.createNewGroup(title: groupTitle)
        }))
        
        self.present(newGroupAlert, animated: true, completion: nil)
    }
    
    @IBAction func unwindFromDirectionStop(_ segue: UIStoryboardSegue)
    {
        self.favoriteStopsTableView.reloadData()
    }
    
    func createNewGroup(title: String)
    {
        let newGroup = NSEntityDescription.insertNewObject(forEntityName: "FavoriteStopGroup", into: CoreDataStack.persistentContainer.viewContext) as! FavoriteStopGroup
        newGroup.groupName = title
        if let parentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup
        {
            newGroup.parentGroup = parentGroup
        }
        newGroup.uuid = UUID().uuidString
        newGroup.favoriteStopUUIDs = try? JSONSerialization.data(withJSONObject: Array<String>(), options: JSONSerialization.WritingOptions.prettyPrinted)
        
        CoreDataStack.saveContext()
        
        openFavoriteGroup(groupObject: newGroup)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        switch FavoriteState.favoritesOrganizeType
        {
        case .addingToGroup:
            self.performSegue(withIdentifier: "UnwindFromFavoriteGroupView", sender: self)
        case .group:
            if FavoriteState.selectedGroupUUID != "0"
            {
                if let currentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup
                {
                    FavoriteState.selectedGroupUUID = currentGroup.parentGroup?.uuid
                }
                self.performSegue(withIdentifier: "UnwindFromFavoriteGroupView", sender: self)
            }
            else
            {
                self.performSegue(withIdentifier: "UnwindFromFavoritesView", sender: self)
            }
        case .list, .route, .stop:
            self.performSegue(withIdentifier: "UnwindFromFavoritesView", sender: self)
        }
    }
    
    @objc func doneAddingToGroup()
    {
        if let favoriteStopsToAddToGroup = favoriteStopsToAddToGroup, let currentGroup = RouteDataManager.fetchLocalObjects(type: "FavoriteStopGroup", predicate: NSPredicate(format: "uuid == %@", FavoriteState.selectedGroupUUID ?? "0"), moc: CoreDataStack.persistentContainer.viewContext)?.first as? FavoriteStopGroup
        {
            if var currentFavoriteStops = try? JSONSerialization.jsonObject(with: currentGroup.favoriteStopUUIDs!, options: JSONSerialization.ReadingOptions.allowFragments) as? Array<String>
            {
                currentFavoriteStops.append(contentsOf: favoriteStopsToAddToGroup)
                currentGroup.favoriteStopUUIDs = try? JSONSerialization.data(withJSONObject: currentFavoriteStops, options: JSONSerialization.WritingOptions.prettyPrinted)
            }
        }
        
        CoreDataStack.saveContext()
        
        //FavoriteState.favoritesOrganizeType = .group
        
        self.performSegue(withIdentifier: "UnwindFromFavoriteGroupView", sender: self)
    }
    
    @IBAction func unwindFromFavoriteGroupView(_ segue: UIStoryboardSegue)
    {
        
    }
}
