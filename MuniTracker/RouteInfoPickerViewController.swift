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

class RouteInfoPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    var routeInfoToChange = Array<NSManagedObject>()
    @IBOutlet weak var routeInfoPicker: UIPickerView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @objc func reloadRouteData()
    {
        routeInfoToChange.removeAll()
        
        switch MapState.routeInfoShowing
        {
        case .none:
            self.view.superview!.isHidden = true
        case .direction:
            self.view.superview!.isHidden = false
            
            routeInfoToChange = (MapState.routeInfoObject as? Route)?.directions?.allObjects as? Array<Direction> ?? Array<Direction>()
        case .stop:
            self.view.superview!.isHidden = false
            
            routeInfoToChange = (MapState.routeInfoObject as? Direction)?.stops?.array as? Array<Stop> ?? Array<Stop>()
        }
        
        routeInfoPicker.reloadAllComponents()
        
        routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
    }
    
    @IBAction func directionButtonPressed(_ sender: Any) {
        switch MapState.routeInfoShowing
        {
        case .direction:
            MapState.routeInfoShowing = .stop
            MapState.routeInfoObject = routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Direction
        case .stop:
            MapState.routeInfoShowing = .direction
            MapState.routeInfoObject = (MapState.routeInfoObject as? Direction)?.route
        default:
            break
        }
        
        reloadRouteData()
    }
}
