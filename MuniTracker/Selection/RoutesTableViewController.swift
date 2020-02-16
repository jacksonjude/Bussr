//
//  RoutesViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit

extension String
{
    subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }
    
    func getUnicodeScalarCharacter(_ i: Int) -> Unicode.Scalar
    {
        return self[i].unicodeScalars[self[i].unicodeScalars.startIndex]
    }
}

class RoutesTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet weak var routesTableView: UITableView!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    
    var selectedRouteObject: Route?
    
    var routeTitleDictionary = Dictionary<String,String>()
    var sortedRouteDictionary = Dictionary<Int,Array<String>>()
    let sectionTitles = ["01", "10", "20", "30", "40", "50", "60", "70", "80", "90", "A", "B"]
    
    //MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        convertRouteObjectsToRouteTitleDictionary()
        convertRouteDictionaryToRouteTitles()
        
        setupThemeElements()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UIApplication.shared.applicationState == .inactive else {
            return
        }

        routesTableView.reloadData()
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            break
        case .dark:
            break
        }
    }
    
    //MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sortedRouteDictionary.keys.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedRouteDictionary[section]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let routeFullTitle = sortedRouteDictionary[indexPath.section]![indexPath.row]
        let routeTag = String(routeFullTitle.split(separator: "–")[0].dropLast())
        let routeObject = RouteDataManager.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", routeTag), moc: CoreDataStack.persistentContainer.viewContext) as? Route
        
        let routeCell = tableView.dequeueReusableCell(withIdentifier: "RouteCell")!
        
        routeCell.textLabel?.text = routeFullTitle
        routeCell.textLabel?.textColor = UIColor(hexString: routeObject?.oppositeColor ?? "FFFFFF")
                
        var routeCellColor = UIColor(hexString: routeObject?.color ?? "000000")
        let hsba = routeCellColor.hsba
        routeCellColor = UIColor(hue: hsba.h, saturation: hsba.s, brightness: hsba.b, alpha: 1)

        routeCell.backgroundColor = (appDelegate.getCurrentTheme() == .dark) ? UIColor.black : UIColor.white
        routeCell.backgroundView = UIView()
        routeCell.backgroundView?.backgroundColor = routeCellColor
        
        let selectedCellBackground = UIView()
        selectedCellBackground.backgroundColor = UIColor(white: 0.7, alpha: 0.4)
        routeCell.selectedBackgroundView = selectedCellBackground
        
        return routeCell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var bulletedSectionTitles = sectionTitles
        var titleIndexOn = 0
        for _ in bulletedSectionTitles
        {
            if titleIndexOn != bulletedSectionTitles.count-1
            {
                bulletedSectionTitles.insert("•", at: titleIndexOn+1)
            }
            titleIndexOn += 2
        }
        return bulletedSectionTitles
    }
        
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index/2
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let routeFullTitle = sortedRouteDictionary[indexPath.section]![indexPath.row].split(separator: "–")
        
        let selectedRouteTag = String(routeFullTitle[0].dropLast())
        
        selectedRouteObject = RouteDataManager.fetchObject(type: "Route", predicate: NSPredicate(format: "tag == %@", selectedRouteTag), moc: CoreDataStack.persistentContainer.viewContext) as? Route
        
        performSegue(withIdentifier: "SelectedRouteUnwind", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SelectedRouteUnwind"
        {
            MapState.routeInfoObject = selectedRouteObject
            MapState.routeInfoShowing = .direction
        }
    }
    
    //MARK: - Route Dictionary
    
    @objc func receiveRouteDictionary(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        if notification.userInfo != nil && notification.userInfo!.count > 0
        {
            routeTitleDictionary = notification.userInfo!["xmlDictionary"] as! Dictionary<String,String>
            
            convertRouteDictionaryToRouteTitles()
        }
    }
    
    func convertRouteObjectsToRouteTitleDictionary()
    {
        let nextBusAgency = RouteDataManager.fetchObject(type: "Agency", predicate: NSPredicate(format: "name == %@", RouteConstants.NextBusAgencyTag), moc: CoreDataStack.persistentContainer.viewContext) as! Agency
        let nextBusAgencyRoutes = (nextBusAgency.routes?.allObjects) as! [Route]
        
        let BARTAgency = RouteDataManager.fetchObject(type: "Agency", predicate: NSPredicate(format: "name == %@", RouteConstants.BARTAgencyTag), moc: CoreDataStack.persistentContainer.viewContext) as! Agency
        let BARTAgencyRoutes = (BARTAgency.routes?.allObjects) as! [Route]
        
        let agencyRoutes = nextBusAgencyRoutes + BARTAgencyRoutes
        
        for route in agencyRoutes
        {
            if route.tag != nil
            {
                routeTitleDictionary[route.tag!] = route.title!
            }
        }
    }
    
    func convertRouteDictionaryToRouteTitles()
    {
        var sectionOn = 0
        for _ in sectionTitles
        {
            sortedRouteDictionary[sectionOn] = Array<String>()
            sectionOn += 1
        }
        
        for routeInfo in routeTitleDictionary
        {
            let routeTitle = routeInfo.key + " – " + routeInfo.value
            
            if (routeInfo.key.count == 1 && CharacterSet.decimalDigits.contains(routeInfo.key.getUnicodeScalarCharacter(0))) || (routeInfo.key.count > 1 && CharacterSet.decimalDigits.contains(routeInfo.key.getUnicodeScalarCharacter(0)) && CharacterSet.letters.contains(routeInfo.key.getUnicodeScalarCharacter(1)))
            {
                sortedRouteDictionary[0]!.append(routeTitle)
            }
            else if CharacterSet.decimalDigits.contains(routeInfo.key.getUnicodeScalarCharacter(0))
            {
                let sectionNumber = Int(String(routeInfo.key[0]))
                sortedRouteDictionary[sectionNumber!]!.append(routeTitle)
            }
            else if routeTitle.contains("BART")
            {
                sortedRouteDictionary[11]!.append(routeTitle)
            }
            else
            {
                sortedRouteDictionary[10]!.append(routeTitle)
            }
        }
        
        for sectionArray in sortedRouteDictionary
        {
            sortedRouteDictionary[sectionArray.key]!.sort {$0.localizedStandardCompare($1) == .orderedAscending}
        }
        
        OperationQueue.main.addOperation {
            self.routesTableView.reloadData()
        }
    }
}
