//
//  RouteCell.swift
//  MuniTracker
//
//  Created by jackson on 2/18/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import UIKit

class RouteCell: UITableViewCell
{
    var route: Route?
    {
        didSet
        {
            self.textLabel?.text = (route?.title ?? "")
            self.textLabel?.textColor = UIColor(hexString: route?.oppositeColor ?? "FFFFFF")
            
            var routeCellColor = UIColor(hexString: route?.color ?? "000000")
            let hsba = routeCellColor.hsba
            routeCellColor = UIColor(hue: hsba.h, saturation: hsba.s, brightness: hsba.b, alpha: 1)
            
            self.backgroundColor = (appDelegate.getCurrentTheme() == .dark) ? UIColor.black : UIColor.white
            self.backgroundView = UIView()
            self.backgroundView?.backgroundColor = routeCellColor
            
            let selectedCellBackground = UIView()
            selectedCellBackground.backgroundColor = UIColor(white: 0.7, alpha: 0.4)
            self.selectedBackgroundView = selectedCellBackground
        }
    }
}
