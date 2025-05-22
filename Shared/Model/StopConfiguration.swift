//
//  StopConfiguration.swift
//  Bussr
//
//  Created by jackson on 8/19/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation

protocol StopConfiguration
{
    var title: String { get set }
    var shortTitle: String { get set }
    var id: String? { get set }
    var tag: String { get set }
    var latitude: Double { get set }
    var longitude: Double { get set }
}

class UmoIQStopConfiguration: StopConfiguration, Decodable
{
    var title: String
    var shortTitle: String
    var id: String?
    var tag: String
    var latitude: Double
    var longitude: Double
    
    enum CodingKeys: String, CodingKey
    {
        case title = "name"
        case shortTitle
        case tag = "id"
        case id = "code"
        case latitude = "lat"
        case longitude = "lon"
    }
    
    required init(from decoder: Decoder) throws
    {
        let decodedContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try decodedContainer.decode(String.self, forKey: .title)
        self.shortTitle = self.title
        self.id = try decodedContainer.decodeIfPresent(String.self, forKey: .id)
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

class BARTStopConfiguration: StopConfiguration, Decodable
{
    var title: String
    var shortTitle: String
    var id: String?
    var tag: String
    var latitude: Double
    var longitude: Double
    
    enum StopCodingKeys: String, CodingKey
    {
        case title, shortTitle = "name"
        case tag = "abbr"
        case latitude = "gtfs_latitude"
        case longitude = "gtfs_longitude"
    }
}

class GTFSStopConfiguration: StopConfiguration, Decodable
{
    var title: String
    var shortTitle: String
    var id: String?
    var tag: String
    var latitude: Double
    var longitude: Double
    
    enum CodingKeys: String, CodingKey
    {
        case title, shortTitle = "stop_name"
        case tag = "stop_id"
        case id = "stop_code"
        case latitude = "stop_lat"
        case longitude = "stop_lon"
    }
}
