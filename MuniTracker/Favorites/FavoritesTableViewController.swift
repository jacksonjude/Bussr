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
    @IBOutlet weak var favoriteStopsTableView: UITableView!
    
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    override func viewDidLoad() {
        reloadTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(finishedCloudFetch(_:)), name: NSNotification.Name("FinishedFetchingFromCloud"), object: nil)
        CloudManager.fetchChangesFromCloud()
        
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
        favoriteStopsTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        //let offWhite = UIColor(white: 0.97647, alpha: 1)
        let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = white
            self.mainNavigationBar.barTintColor = nil
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
        case .dark:
            self.view.backgroundColor = black
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        }
    }
    
    func fetchFavoriteStops()
    {
        if let favoriteStops = RouteDataManager.fetchLocalObjects(type: "FavoriteStop", predicate: NSPredicate(format: "TRUEPREDICATE"), moc: appDelegate.persistentContainer.viewContext) as? [FavoriteStop]
        {
            favoriteStopObjects = favoriteStops
        }
    }
    
    func sortFavoriteStops()
    {
        if var favoriteStops = favoriteStopObjects
        {
            favoriteStops.sort(by: {
                if let direction1 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $0.directionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction, let direction2 = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", $1.directionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction
                {
                    return direction1.route!.routeTitle! < direction2.route!.routeTitle!
                }
                else
                {
                    return true
                }
            })
            
            favoriteStopObjects = favoriteStops
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favoriteStopObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let favoriteStopCell = tableView.dequeueReusableCell(withIdentifier: "FavoriteStopCell")!
        
        let favoriteStopObject = favoriteStopObjects![indexPath.row]
        
        var textColor = UIColor.black
        
        if let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", favoriteStopObject.directionTag!), moc: appDelegate.persistentContainer.viewContext).object as? Direction
        {
            if let routeColor = direction.route?.routeColor, let routeOppositeColor = direction.route?.routeOppositeColor
            {
                favoriteStopCell.backgroundColor = UIColor(hexString: routeColor)
                
                textColor = UIColor(hexString: routeOppositeColor)
            }
            
            (favoriteStopCell.viewWithTag(601) as! UILabel).text = direction.directionTitle
            (favoriteStopCell.viewWithTag(600) as! UILabel).text = direction.route?.routeTag
            
            (favoriteStopCell.viewWithTag(601) as! UILabel).textColor = textColor
            (favoriteStopCell.viewWithTag(600) as! UILabel).textColor = textColor
        }
        
        if let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStopObject.stopTag!), moc: appDelegate.persistentContainer.viewContext).object as? Stop
        {
            (favoriteStopCell.viewWithTag(602) as! UILabel).text = stop.stopTitle
            (favoriteStopCell.viewWithTag(602) as! UILabel).textColor = textColor
        }
        
        
        (favoriteStopCell.viewWithTag(603) as! UILabel).textColor = textColor
        
        return favoriteStopCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteStop = favoriteStopObjects![indexPath.row]
        
        MapState.selectedDirectionTag = favoriteStop.directionTag
        MapState.selectedStopTag = favoriteStop.stopTag
        MapState.routeInfoShowing = .stop
        MapState.routeInfoObject = RouteDataManager.getCurrentDirection()
        
        self.performSegue(withIdentifier: "SelectedFavoriteUnwind", sender: self)
    }
}
