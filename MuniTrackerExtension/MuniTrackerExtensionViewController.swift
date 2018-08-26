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

class MuniTrackerExtensionViewController: UITableViewController, NCWidgetProviding {
    var favoriteStops: Array<FavoriteStop>?
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
        return favoriteStops?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RouteCell")!
        
        let favoriteStopObject = favoriteStops![indexPath.row]
        
        let routeTagLabel = cell.viewWithTag(600) as! UILabel
        let stopNameLabel = cell.viewWithTag(601) as! UILabel
        
        if let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", favoriteStopObject.directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction, let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStopObject.stopTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop
        {
            routeTagLabel.text = direction.route?.routeTag
            stopNameLabel.text = stop.stopTitle
            
            if let routeColor = direction.route?.routeColor
            {
                cell.backgroundColor = UIColor(hexString: routeColor)
            }
            if let routeOppositeColor = direction.route?.routeOppositeColor
            {
                routeTagLabel.textColor = UIColor(hexString: routeOppositeColor)
                stopNameLabel.textColor = UIColor(hexString: routeOppositeColor)
                (cell.viewWithTag(602) as! UILabel).textColor = UIColor(hexString: routeOppositeColor)
            }
            
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
            NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTime(notification:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteStopObject = favoriteStops![indexPath.row]
        
        if let direction = RouteDataManager.fetchOrCreateObject(type: "Direction", predicate: NSPredicate(format: "directionTag == %@", favoriteStopObject.directionTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Direction, let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStopObject.stopTag!), moc: CoreDataStack.persistentContainer.viewContext).object as? Stop
        {
            let predictionTimesReturnUUID = UUID().uuidString + ";" + String(indexPath.row)
            NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTime(notification:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
            
            RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stop, direction: direction)
        }
    }
    
    @objc func receivePredictionTime(notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
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
            
            let indexRow = Int(notification.name.rawValue.split(separator: ";")[1]) ?? 0
            
            OperationQueue.main.addOperation {
                if let favoritesPredictionLabel = self.tableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.viewWithTag(602) as? UILabel
                {
                    favoritesPredictionLabel.text = predictionsString
                }
                
                if self.tableView.cellForRow(at: IndexPath(row: indexRow, section: 0))?.isSelected ?? false
                {
                    self.tableView.deselectRow(at: IndexPath(row: indexRow, section: 0), animated: true)
                }
            }
        }
    }
}
