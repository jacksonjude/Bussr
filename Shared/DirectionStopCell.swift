//
//  RouteStopCell.swift
//  MuniTracker
//
//  Created by jackson on 4/24/19.
//  Copyright © 2019 jackson. All rights reserved.
//

import Foundation
import UIKit

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

class DirectionStopCell: UITableViewCell
{
    var includeMins = true
    var directionObject: Direction?
    var stopObject: Stop?
    
    func updateCellText()
    {
        var textColor = UIColor.black
        
        if let routeColor = directionObject?.route?.routeColor, let routeOppositeColor = directionObject?.route?.routeOppositeColor
        {
            self.backgroundColor = UIColor(hexString: routeColor)
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        (self.viewWithTag(600) as? UILabel)?.textColor = textColor
        (self.viewWithTag(601) as? UILabel)?.textColor = textColor
        (self.viewWithTag(602) as? UILabel)?.textColor = textColor
        (self.viewWithTag(603) as? UILabel)?.textColor = textColor
        (self.viewWithTag(604) as? UILabel)?.textColor = textColor
        
        (self.viewWithTag(600) as? UILabel)?.text = directionObject?.route?.routeTag
        (self.viewWithTag(601) as? UILabel)?.text = directionObject?.directionTitle
        (self.viewWithTag(602) as? UILabel)?.text = stopObject?.stopTitle
        (self.viewWithTag(604) as? UILabel)?.text = directionObject?.directionName
    }
    
    func refreshTimes()
    {
        if let stopObject = self.stopObject, let directionObject = self.directionObject
        {
            fetchPrediction(stopObject: stopObject, directionObject: directionObject)
        }
    }
    
    func fetchPrediction(stopObject: Stop, directionObject: Direction)
    {
        let predictionTimesReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receivePrediction(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID, stop: stopObject, direction: directionObject)
    }
    
    @objc func receivePrediction(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        if let predictions = notification.userInfo!["predictions"] as? [String]
        {
            OperationQueue.main.addOperation {
                var predictionsString = RouteDataManager.formatPredictions(predictions: predictions).predictionsString
                
                if !self.includeMins && predictionsString.contains(" mins")
                {
                    predictionsString.removeSubrange(Range<String.Index>(NSRange(location: predictionsString.count-5, length: 5), in: predictionsString)!)
                }
                
                if let stopPredictionLabel = self.viewWithTag(603) as? UILabel
                {
                    stopPredictionLabel.text = predictionsString
                }
            }
        }
    }
}
