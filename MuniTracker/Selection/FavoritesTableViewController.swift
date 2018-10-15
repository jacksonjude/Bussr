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
    @IBOutlet weak var organizeSegmentControl: UISegmentedControl!
    @IBOutlet weak var favoriteStopsTableView: UITableView!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    
    override func viewDidLoad() {        
        reloadTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(finishedCloudFetch(_:)), name: NSNotification.Name("FinishedFetchingFromCloud"), object: nil)
        CloudManager.fetchChangesFromCloud()
        
        organizeSegmentControl.selectedSegmentIndex = FavoriteState.favoritesOrganizeType.rawValue
        
        setupThemeElements()
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
        case .list:
            break
        case .stop:
            fetchStopSet()
            sortStopSet()
        case .route:
            fetchRouteSet()
            sortRouteSet()
        }
        
        favoriteStopsTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
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
        
        if let predictions = notification.userInfo!["predictions"] as? [String], FavoriteState.favoritesOrganizeType == .list
        {
            OperationQueue.main.addOperation {
                let predictionsString = MapState.formatPredictions(predictions: predictions).predictionsString
                let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
                
                if let favoritesPredictionLabel = self.favoriteStopsTableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                {
                    self.loadedPredictions[indexRow] = true
                    favoritesPredictionLabel.text = predictionsString
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if FavoriteState.favoritesOrganizeType == .list && !loadedPredictions[indexPath.row]
        {
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
            let favoriteStop = favoriteStopObjects![indexPath.row]
            NotificationCenter.default.addObserver(self, selector: #selector(receiveFavoritesPrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            if let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!), let direction = RouteDataManager.fetchDirection(directionTag: favoriteStop.directionTag!)
            {
                RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch FavoriteState.favoritesOrganizeType
        {
        case .list:
            return favoriteStopObjects?.count ?? 0
        case .stop:
            return favoriteStopSet?.count ?? 0
        case .route:
            return favoriteRouteSet?.count ?? 0
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var textColor = UIColor.black
        
        switch FavoriteState.favoritesOrganizeType
        {
        case .list:
            let favoriteRouteCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteRouteCell")!
            let favoriteStopObject = favoriteStopObjects![indexPath.row]
            
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
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch FavoriteState.favoritesOrganizeType
        {
        case .list:
            let favoriteStop = favoriteStopObjects![indexPath.row]
            
            MapState.selectedDirectionTag = favoriteStop.directionTag
            MapState.selectedStopTag = favoriteStop.stopTag
            MapState.routeInfoShowing = .stop
            MapState.routeInfoObject = MapState.getCurrentDirection()
            
            self.performSegue(withIdentifier: "SelectedFavoriteUnwind", sender: self)
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
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDirectionStopTableView", let directionStopViewController = segue.destination as? DirectionsTableViewController
        {
            directionStopViewController.unwindSegueID = "UnwindFromDirectionStop"
        }
    }
    
    @IBAction func listStopSegmentPressed(_ sender: Any) {
        let segmentControl = sender as! UISegmentedControl
        
        FavoriteState.favoritesOrganizeType = FavoriteState.FavoritesOrganizeType(rawValue: segmentControl.selectedSegmentIndex) ?? .list
        
        reloadTableView()
    }
    
    @IBAction func unwindFromDirectionStop(_ segue: UIStoryboardSegue)
    {
        self.favoriteStopsTableView.reloadData()
    }
}
