//
//  RouteConfiguration.swift
//  Bussr
//
//  Created by jackson on 8/19/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation
import UIKit

struct UmoIQRouteID: Codable
{
    let tag: String
    let title: String
    let revision: Int

    enum CodingKeys: String, CodingKey
    {
        case tag = "id"
        case title
        case revision = "rev"
    }
}

class NextBusRouteList: Decodable
{
    var routeObjects: [NextBusRouteInfo]
    
    enum BaseRouteCodingKeys: String, CodingKey
    {
        case route
    }
    
    class NextBusRouteInfo: Decodable
    {
        var tag: String
        var title: String
        
        enum RouteInfoCodingKeys: String, CodingKey
        {
            case tag
            case title
        }
        
        required init(from decoder: Decoder) throws
        {
            let decodedContainer = try decoder.container(keyedBy: RouteInfoCodingKeys.self)
            
            self.tag = try decodedContainer.decode(String.self, forKey: .tag)
            self.title = try decodedContainer.decode(String.self, forKey: .title)
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let baseContainer = try decoder.container(keyedBy: BaseRouteCodingKeys.self)
        self.routeObjects = try baseContainer.decode([NextBusRouteInfo].self, forKey: .route)
    }
}

protocol RouteConfiguration: Decodable
{
    var tag: String { get set }
    var title: String { get set }
    var color: String { get set }
    var oppositeColor: String { get set }
    var revision: Int? { get set }
    
    var directions: [DirectionConfiguration] { get set }
    var stops: [StopConfiguration] { get set }
}

class UmoIQRouteConfiguration: RouteConfiguration
{
    var tag: String
    var title: String
    var color: String
    var oppositeColor: String
    var revision: Int?
    var directions: [DirectionConfiguration]
    var stops: [StopConfiguration]
    
    enum CodingKeys: String, CodingKey
    {
        case tag = "id"
        case title
        case color
        case oppositeColor = "textColor"
        case revision = "rev"
        case directions
        case stops
    }
    
    required init(from decoder: Decoder) throws
    {
        let routeContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        self.tag = try routeContainer.decode(String.self, forKey: .tag)
        self.title = try routeContainer.decode(String.self, forKey: .title)
        self.color = try routeContainer.decode(String.self, forKey: .color)
        self.oppositeColor = try routeContainer.decode(String.self, forKey: .oppositeColor)
        self.revision = try? routeContainer.decode(Int.self, forKey: .revision)
        
        self.directions = try routeContainer.decode([UmoIQDirectionConfiguration].self, forKey: .directions)
        self.stops = try routeContainer.decode([UmoIQStopConfiguration].self, forKey: .stops)
    }
}

class NextBusRouteConfiguration: RouteConfiguration
{
    var tag: String
    var title: String
    var color: String
    var oppositeColor: String
    var revision: Int?
    var directions: [DirectionConfiguration]
    var stops: [StopConfiguration]
    var scheduleJSON: String?
    
    enum BaseRouteCodingKeys: String, CodingKey
    {
        case route
    }
    
    enum RouteCodingKeys: String, CodingKey
    {
        case tag
        case title
        case color
        case oppositeColor
        
        case directionConfiguration = "direction"
        case stopConfiguration = "stop"
    }
    
    required init(from decoder: Decoder) throws
    {
        let baseContainer = try decoder.container(keyedBy: BaseRouteCodingKeys.self)
        let routeContainer = try baseContainer.nestedContainer(keyedBy: RouteCodingKeys.self, forKey: .route)
        
        self.tag = try routeContainer.decode(String.self, forKey: .tag)
        self.title = try routeContainer.decode(String.self, forKey: .title)
        self.color = try routeContainer.decode(String.self, forKey: .color)
        //self.oppositeColor = try routeContainer.decode(String.self, forKey: .oppositeColor)
        self.oppositeColor = "FFFFFF"
        
        var directions = try? routeContainer.decode([NextBusDirectionConfiguration].self, forKey: .directionConfiguration)
        if directions == nil
        {
            directions = [try routeContainer.decode(NextBusDirectionConfiguration.self, forKey: .directionConfiguration)]
        }
        self.directions = directions ?? []
        
        self.stops = try routeContainer.decode([NextBusStopConfiguration].self, forKey: .stopConfiguration)
        
        self.revision = nil
    }
}

class BARTRouteList: Decodable
{
    var routeObjects: [BARTRouteInfo]
    
    enum RootRouteCodingKeys: String, CodingKey
    {
        case root
    }
    
    enum BaseRoutesCodingKeys: String, CodingKey
    {
        case routes
    }
    
    enum BaseRouteCodingKeys: String, CodingKey
    {
        case route
    }
    
    class BARTRouteInfo: Decodable
    {
        var abbr: String
        var number: String
        
        enum RouteInfoCodingKeys: String, CodingKey
        {
            case abbr
            case number
        }
        
        required init(from decoder: Decoder) throws
        {
            let decodedContainer = try decoder.container(keyedBy: RouteInfoCodingKeys.self)
            
            self.abbr = try decodedContainer.decode(String.self, forKey: .abbr)
            self.number = try decodedContainer.decode(String.self, forKey: .number)
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let rootContainer = try decoder.container(keyedBy: RootRouteCodingKeys.self)
        let baseRoutesContainer = try rootContainer.nestedContainer(keyedBy: BaseRoutesCodingKeys.self, forKey: .root)
        let baseRouteContainer = try baseRoutesContainer.nestedContainer(keyedBy: BaseRouteCodingKeys.self, forKey: .routes)
        self.routeObjects = try baseRouteContainer.decode([BARTRouteInfo].self, forKey: .route)
    }
}

class BARTRouteConfiguration: RouteConfiguration
{
    var tag: String
    var abbr: String
    var title: String
    var color: String
    var oppositeColor: String
    var revision: Int?
    var directions: [DirectionConfiguration]
    var stops: [StopConfiguration]
    
    enum RootRouteCodingKeys: String, CodingKey
    {
        case root
    }
    
    enum BaseRoutesCodingKeys: String, CodingKey
    {
        case routes
    }
    
    enum BaseRouteCodingKeys: String, CodingKey
    {
        case route
    }
    
    enum RouteCodingKeys: String, CodingKey
    {
        case name
        case abbr
        case number
        case origin
        case destination
        case color = "hexcolor"
        
        case directionConfiguration = "config"
    }
    
    required init(from decoder: Decoder) throws
    {
        let rootContainer = try decoder.container(keyedBy: RootRouteCodingKeys.self)
        let baseRoutesContainer = try rootContainer.nestedContainer(keyedBy: BaseRoutesCodingKeys.self, forKey: .root)
        let baseRouteContainer = try baseRoutesContainer.nestedContainer(keyedBy: BaseRouteCodingKeys.self, forKey: .routes)
        let routeContainer = try baseRouteContainer.nestedContainer(keyedBy: RouteCodingKeys.self, forKey: .route)
        
        self.tag = try routeContainer.decode(String.self, forKey: .number)
        self.abbr = try routeContainer.decode(String.self, forKey: .abbr)
        self.title = try routeContainer.decode(String.self, forKey: .name)
        self.color = try routeContainer.decode(String.self, forKey: .color)
        self.color.remove(at: self.color.startIndex) // Remove # from color
        
        let colorBrightness = UIColor(hexString: self.color).hsba.b
        self.oppositeColor = colorBrightness > 0.8 ? "000000" : "FFFFFF"
        
        self.directions = []
        self.stops = []
        
        if let direction = try? baseRouteContainer.decode(BARTDirectionConfiguration.self, forKey: .route)
        {
            directions.append(direction)
        }
        
        self.revision = nil
    }
    
    func loadStops(from stopArray: [BARTStopConfiguration]) throws
    {
        guard let directionConfig = self.directions.first else { return }
        for stopConfig in stopArray
        {
            if directionConfig.stopTags.contains(where: { (stopTagConfig) -> Bool in
                stopTagConfig.tag == stopConfig.tag
            })
            {
                self.stops.append(stopConfig)
            }
        }
    }
}
