//
//  TodayViewController.swift
//  MuniTrackerExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation


class MuniTrackerExtensionViewController: UITableViewController, NCWidgetProviding {
    var stopDirectionObjects: Array<(stopTag: String, directionTag: String)>?
    var stops: Array<Stop>?
    
    let numStopsToDisplay = 4
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        self.preferredContentSize = (activeDisplayMode != .expanded) ? maxSize : CGSize(width: maxSize.width, height: 220)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stopDirectionObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RouteCell") as! DirectionStopCell
        
        cell.includeMins = false
        
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        if let stop = RouteDataManager.fetchStop(stopTag: stopDirectionObject.stopTag), let direction = RouteDataManager.fetchDirection(directionTag: stopDirectionObject.directionTag)
        {
            cell.directionObject = direction
            cell.stopObject = stop
            cell.updateCellText()
            
            cell.refreshTimes()
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        (tableView.cellForRow(at: indexPath) as? DirectionStopCell)?.refreshTimes()
    }
}
