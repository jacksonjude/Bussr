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
        
        let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        //let routeTagLabel = cell.viewWithTag(600) as! UILabel
        //let stopNameLabel = cell.viewWithTag(601) as! UILabel
        
        if let stop = RouteDataManager.fetchStop(stopTag: stopDirectionObject.stopTag), let direction = RouteDataManager.fetchDirection(directionTag: stopDirectionObject.directionTag)
        {
            /*routeTagLabel.text = direction.route?.routeTag
            stopNameLabel.text = stop.stopTitle
            
            if let routeColor = direction.route?.routeColor
            {
                cell.backgroundColor = UIColor(hexString: routeColor)
            }
            if let routeOppositeColor = direction.route?.routeOppositeColor
            {
                routeTagLabel.textColor = UIColor(hexString: routeOppositeColor)
                stopNameLabel.textColor = UIColor(hexString: routeOppositeColor)
                (cell.viewWithTag(603) as! UILabel).textColor = UIColor(hexString: routeOppositeColor)
            }
            
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
            NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTime(notification:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)*/
            
            cell.directionObject = direction
            cell.stopObject = stop
            cell.updateCellText()
            
            cell.refreshTimes()
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        /*let stopDirectionObject = stopDirectionObjects![indexPath.row]
        
        if let stop = RouteDataManager.fetchStop(stopTag: stopDirectionObject.stopTag), let direction = RouteDataManager.fetchDirection(directionTag: stopDirectionObject.directionTag)
        {
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
            NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTime(notification:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
        }*/
        
        (tableView.cellForRow(at: indexPath) as? DirectionStopCell)?.refreshTimes()
    }
    
    /*@objc func receivePredictionTime(notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
        
        if let predictions = notification.userInfo?["predictions"] as? Array<String>
        {
            var predictionOn = 0
            var predictionsString = ""
            for prediction in predictions
            {
                if predictionOn != 0
                {
                    predictionsString += ", "
                }
                
                if prediction == "0"
                {
                    predictionsString += "Now"
                }
                else
                {
                    predictionsString += prediction
                }
                
                predictionOn += 1
            }
            //predictionsString += " mins"
            
            if predictions.count > 0
            {
                OperationQueue.main.addOperation {
                    if let favoritesPredictionLabel = self.tableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(603) as? UILabel
                    {
                        favoritesPredictionLabel.text = predictionsString
                    }
                    
                    if self.tableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.isSelected ?? false
                    {
                        self.tableView.deselectRow(at: IndexPath(row: indexRow, section: 0), animated: true)
                    }
                }
            }
            /*else if favoriteStops?.count ?? 0 > indexRow
            {
                stops?.removeAll(where: { (stop) -> Bool in
                    return favoriteStops?[indexRow].stopTag == stop.stopTag
                })
                favoriteStops?.remove(at: indexRow)
                
                tableView.reloadData()
            }*/
        }
    }*/
}
