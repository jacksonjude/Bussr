//
//  StopConfiguration.swift
//  Bussr
//
//  Created by jackson on 8/19/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation

protocol StopConfiguration: Decodable
{
    var title: String { get set }
    var shortTitle: String { get set }
    var id: String? { get set }
    var tag: String { get set }
    var latitude: Double { get set }
    var longitude: Double { get set }
}

class NextBusStopConfiguration: StopConfiguration
{
    var title: String
    var shortTitle: String
    var id: String?
    var tag: String
    var latitude: Double
    var longitude: Double
    
    enum StopCodingKeys: String, CodingKey
    {
        case title
        case shortTitle
        case id = "code"
        case tag = "id"
        case latitude = "lat"
        case longitude = "lon"
    }
    
    required init(from decoder: Decoder) throws
    {
        let decodedContainer = try decoder.container(keyedBy: StopCodingKeys.self)
        
        let title = try decodedContainer.decode(String.self, forKey: .title)
        self.title = title
        self.shortTitle = try decodedContainer.decodeIfPresent(String.self, forKey: .shortTitle) ?? title
        self.id = try decodedContainer.decode(String.self, forKey: .id)
        self.tag = try decodedContainer.decode(String.self, forKey: .tag)
        self.latitude = try decodedContainer.decode(Double.self, forKey: .latitude)
        self.longitude = try decodedContainer.decode(Double.self, forKey: .longitude)
    }
}

class BARTStopArray: Decodable
{
    var stops: [BARTStopConfiguration]
    
    enum RootStopCodingKeys: String, CodingKey
    {
        case root
    }
    
    enum BaseStationsCodingKeys: String, CodingKey
    {
        case stations
    }
    
    enum BaseStationCodingKeys: String, CodingKey
    {
        case station
    }
    
    required init(from decoder: Decoder) throws
    {
        let rootContainer = try decoder.container(keyedBy: RootStopCodingKeys.self)
        let baseStationsContainer = try rootContainer.nestedContainer(keyedBy: BaseStationsCodingKeys.self, forKey: .root)
        let baseStationContainer = try baseStationsContainer.nestedContainer(keyedBy: BaseStationCodingKeys.self, forKey: .stations)
        
        self.stops = try baseStationContainer.decode([BARTStopConfiguration].self, forKey: .station)
    }
}

class BARTStopConfiguration: StopConfiguration
{
    var title: String
    var shortTitle: String
    var id: String?
    var tag: String
    var latitude: Double
    var longitude: Double
    
    enum StopCodingKeys: String, CodingKey
    {
        case title = "name"
        case tag = "abbr"
        case latitude = "gtfs_latitude"
        case longitude = "gtfs_longitude"
    }
    
    required init(from decoder: Decoder) throws
    {
        let decodedContainer = try decoder.container(keyedBy: StopCodingKeys.self)
        
        let title = try decodedContainer.decode(String.self, forKey: .title)
        self.title = title
        self.shortTitle = title
        self.tag = try decodedContainer.decode(String.self, forKey: .tag)
        self.latitude = Double(try decodedContainer.decode(String.self, forKey: .latitude))!
        self.longitude = Double(try decodedContainer.decode(String.self, forKey: .longitude))!
    }
}
