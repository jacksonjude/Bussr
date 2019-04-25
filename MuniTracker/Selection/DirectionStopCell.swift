//
//  RouteStopCell.swift
//  MuniTracker
//
//  Created by jackson on 4/24/19.
//  Copyright © 2019 jackson. All rights reserved.
//

import Foundation
import UIKit

class DirectionStopCell: UITableViewCell
{
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
        
        (self.viewWithTag(600) as? UILabel)?.text = directionObject?.route?.routeTag
        (self.viewWithTag(601) as? UILabel)?.text = directionObject?.directionTitle
        (self.viewWithTag(602) as? UILabel)?.text = stopObject?.stopTitle
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
                let predictionsString = MapState.formatPredictions(predictions: predictions).predictionsString
                
                if let stopPredictionLabel = self.viewWithTag(603) as? UILabel
                {
                    stopPredictionLabel.text = predictionsString
                }
            }
        }
    }
}
