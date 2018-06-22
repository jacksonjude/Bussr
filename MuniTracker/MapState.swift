//
//  MapState.swift
//  MuniTracker
//
//  Created by jackson on 6/20/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import CoreData

class MapState: NSObject
{
    enum RouteInfoType: Int
    {
        case none
        case direction
        case stop
    }
    
    static var routeInfoShowing: RouteInfoType = .none
    static var routeInfoObject: NSManagedObject? = nil
    
    static var selectedDirectionTag: String? = nil
    static var selectedStopTag: String? = nil
}
