//
//  StopRowController.swift
//  MuniTrackerWatchApp Extension
//
//  Created by jackson on 2/9/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import WatchKit

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
    
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) = (0, 0, 0, 0)
        self.getHue(&(hsba.h), saturation: &(hsba.s), brightness: &(hsba.b), alpha: &(hsba.a))
        return hsba
    }
}

class DirectionStopRowController: NSObject
{
    @IBOutlet weak var routeLabel: WKInterfaceLabel!
    @IBOutlet weak var stopLabel: WKInterfaceLabel!
    @IBOutlet weak var predictionTimesLabel: WKInterfaceLabel!
    @IBOutlet weak var directionStopRowGroup: WKInterfaceGroup!
    @IBOutlet weak var activityIndicatorImage: WKInterfaceImage!
    
    var directionStop: (stop: Stop, direction: Direction)?
    {
        didSet
        {
            updateCellText()
        }
    }
    
    var includeMins = false
    
    func updateCellText()
    {
        var textColor = UIColor.black
        
        if let routeColor = directionStop?.direction.route?.color, let routeOppositeColor = directionStop?.direction.route?.oppositeColor
        {
            directionStopRowGroup.setBackgroundColor(UIColor(hexString: routeColor))
            textColor = UIColor(hexString: routeOppositeColor)
        }
        
        routeLabel.setTextColor(textColor)
        stopLabel.setTextColor(textColor)
        predictionTimesLabel.setTextColor(textColor)
        
        routeLabel.setText(directionStop?.direction.route?.tag)
        stopLabel.setText(directionStop?.stop.title)
    }
    
    func refreshTimes()
    {
        if let stopObject = self.directionStop?.stop, let directionObject = self.directionStop?.direction
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
                var predictionsString = RouteDataManager.formatPredictions(predictions: predictions, vehicleIDs: nil, predictionsToShow: 4).predictionsString
                
                if !self.includeMins && predictionsString.contains(" mins")
                {
                    predictionsString.removeSubrange(Range<String.Index>(NSRange(location: predictionsString.count-5, length: 5), in: predictionsString)!)
                }
                
                if self.predictionTimesLabel == nil { return }
                self.predictionTimesLabel.setText(predictionsString)
                self.stopActivityIndicator()
            }
        }
    }
    
    func startActivityIndicator()
    {
        activityIndicatorImage.setHidden(false)
        activityIndicatorImage.setImageNamed("Activity")
        activityIndicatorImage.startAnimatingWithImages(in: NSRange(location: 0, length: 30), duration: 1.0, repeatCount: 0)
    }
    
    func stopActivityIndicator()
    {
        activityIndicatorImage.stopAnimating()
        activityIndicatorImage.setImageNamed(nil)
        activityIndicatorImage.setHidden(true)
    }
}
