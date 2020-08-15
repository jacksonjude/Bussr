//
//  RouteInfoPanelTipViewController.swift
//  Bussr
//
//  Created by jackson on 2/8/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import UIKit

class RouteInfoPanelTipViewController: UIViewController
{
    var mainMapViewController: MainMapViewController?
    
    @IBAction func routeListPressed(_ sender: Any) {
        mainMapViewController?.routesButtonPressed(sender)
    }
    
    @IBAction func nearbyPressed(_ sender: Any) {
        mainMapViewController?.nearbyButtonPressed(sender)
    }
    
    @IBAction func favoritesPressed(_ sender: Any) {
        mainMapViewController?.favoritesButtonPressed(sender)
    }
    
    @IBAction func recentPressed(_ sender: Any) {
        mainMapViewController?.historyButtonPressed(sender)
    }
}
