//
//  RouteInfoPickerViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit

class RouteInfoPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    enum RouteInfoType: Int
    {
        case none
        case direction
        case stop
    }
    
    var routeInfoToChangeDictionary: Dictionary<Int,Array<String>>? = nil
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return routeInfoToChangeDictionary?.keys.count ?? 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return routeInfoToChangeDictionary?[component]?.count ?? 0
    }
    
    
}
