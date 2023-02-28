//
//  RoutesViewController.swift
//  Bussr
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
    
    var routeArray = Array<Route>()
    var sortedRouteDictionary = Dictionary<Int,Array<Route>>()
    let sectionTitles = ["01", "10", "20", "30", "40", "50", "60", "70", "80", "90", "A", "B"]
    
    //MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchRoutes()
        sortRoutes()
        
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
        let routeObject = sortedRouteDictionary[indexPath.section]![indexPath.row]
        
        let routeCell = tableView.dequeueReusableCell(withIdentifier: "RouteCell") as! RouteCell
        routeCell.route = routeObject
        
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
        selectedRouteObject = sortedRouteDictionary[indexPath.section]![indexPath.row]
        
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
    
    func fetchRoutes()
    {
        var nextBusAgencyRoutes = [Route]()
        if let nextBusAgency = CoreDataStack.fetchObject(type: "Agency", predicate: NSPredicate(format: "name == %@", UmoIQAgency.agencyTag), moc: CoreDataStack.persistentContainer.viewContext) as? Agency
        {
            nextBusAgencyRoutes = (nextBusAgency.routes?.allObjects) as? [Route] ?? []
        }
        
        var BARTAgencyRoutes = [Route]()
        if let BARTAgency = CoreDataStack.fetchObject(type: "Agency", predicate: NSPredicate(format: "name == %@", BARTAgency.agencyTag), moc: CoreDataStack.persistentContainer.viewContext) as? Agency
        {
            BARTAgencyRoutes = (BARTAgency.routes?.allObjects) as? [Route] ?? []
        }
        
        var agencyRoutes = nextBusAgencyRoutes + BARTAgencyRoutes
        agencyRoutes.removeAll { (route) -> Bool in
            return route.title == nil
        }
        
        self.routeArray = agencyRoutes
    }
    
    func sortRoutes()
    {
        var sectionOn = 0
        for _ in sectionTitles
        {
            sortedRouteDictionary[sectionOn] = Array<Route>()
            sectionOn += 1
        }
        
        for route in routeArray
        {
            let routeTag = route.tag ?? ""
            
            if (routeTag.count == 1 && CharacterSet.decimalDigits.contains(routeTag.getUnicodeScalarCharacter(0))) || (routeTag.count > 1 && CharacterSet.decimalDigits.contains(routeTag.getUnicodeScalarCharacter(0)) && CharacterSet.letters.contains(routeTag.getUnicodeScalarCharacter(1)))
            {
                sortedRouteDictionary[0]!.append(route)
            }
            else if CharacterSet.decimalDigits.contains(routeTag.getUnicodeScalarCharacter(0))
            {
                let sectionNumber = Int(String(routeTag[0]))
                sortedRouteDictionary[sectionNumber!]!.append(route)
            }
            else if routeTag.contains(BARTAPI.BARTAgencyTag)
            {
                sortedRouteDictionary[11]!.append(route)
            }
            else
            {
                sortedRouteDictionary[10]!.append(route)
            }
        }
        
        for sectionArray in sortedRouteDictionary
        {
            sortedRouteDictionary[sectionArray.key]!.sort {($0.tag ?? "").localizedStandardCompare($1.tag ?? "") == .orderedAscending}
        }
        
        OperationQueue.main.addOperation {
            self.routesTableView.reloadData()
        }
    }
}
