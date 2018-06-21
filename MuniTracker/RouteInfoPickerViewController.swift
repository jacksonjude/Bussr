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
    var routeInfoToChange: Array<Array<String>>? = nil
    @IBOutlet weak var routeInfoPicker: UIPickerView!
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return routeInfoToChange?.count ?? 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return routeInfoToChange?[component].count ?? 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @objc func reloadRouteData()
    {
        switch MapState.routeInfoShowing
        {
        case .none:
            self.view.superview!.isHidden = true
        case .direction,.stop:
            self.view.superview!.isHidden = false
        }
        
        switch MapState.routeInfoShowing
        {
        case .direction:
            break
        case .stop:
            break
        default:
            break
        }
    }
}
