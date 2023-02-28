//
//  DirectionConfiguration.swift
//  Bussr
//
//  Created by jackson on 8/19/20.
//  Copyright © 2020 jackson. All rights reserved.
//

import Foundation

protocol DirectionConfiguration: Decodable
{
    var title: String { get set }
    var tag: String { get set }
    var name: String { get set }
    var useForUI: Bool { get set }
    var stopTags: [StopTagConfiguration] { get set }
}

protocol StopTagConfiguration: Decodable
{
    var tag: String { get set }
}

class UmoIQDirectionConfiguration: DirectionConfiguration
{
    var title: String
    var tag: String
    var name: String
    var useForUI: Bool
    var stopTags: [StopTagConfiguration]
    
    class UmoIQStopTagConfiguration: StopTagConfiguration, Codable
    {
        var tag: String
        
        required init(from decoder: Decoder) throws
        {
            let singleValueContainer = try decoder.singleValueContainer()
            
            self.tag = try singleValueContainer.decode(String.self)
        }
    }
    
    enum CodingKeys: String, CodingKey
    {
        case title = "name"
        case name = "shortName"
        case tag = "id"
        case useForUI = "useForUi"
        case stopTags = "stops"
    }
    
    required init(from decoder: Decoder) throws
    {
        let directionContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try directionContainer.decode(String.self, forKey: .title)
        self.tag = try directionContainer.decode(String.self, forKey: .tag)
        self.name = try directionContainer.decode(String.self, forKey: .name)
        self.useForUI = try directionContainer.decode(Bool.self, forKey: .useForUI)
        
        self.stopTags = try directionContainer.decode([UmoIQStopTagConfiguration].self, forKey: .stopTags)
    }
}

class BARTDirectionConfiguration: DirectionConfiguration
{
    var title: String
    var tag: String
    var name: String
    var useForUI: Bool
    
    var stopTags: [StopTagConfiguration]
    
    enum DirectionCodingKeys: String, CodingKey
    {
        case title = "name"
        case tag = "abbr"
        case name = "direction"
        
        case stopConfig = "config"
    }
    
    enum StopsCodingKeys: String, CodingKey
    {
        case stops = "station"
    }
    
    class BARTStopTagConfiguration: StopTagConfiguration
    {
        var tag: String
        
        required init(from decoder: Decoder) throws
        {
            let stringContainer = try decoder.singleValueContainer()
            self.tag = try stringContainer.decode(String.self)
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let decodedContainer = try decoder.container(keyedBy: DirectionCodingKeys.self)
        
        self.title = try decodedContainer.decode(String.self, forKey: .title)
        self.tag = try decodedContainer.decode(String.self, forKey: .tag)
        self.name = try decodedContainer.decode(String.self, forKey: .name)
        self.useForUI = true
        
        let stopConfigContainer = try decodedContainer.nestedContainer(keyedBy: StopsCodingKeys.self, forKey: .stopConfig)
        self.stopTags = try stopConfigContainer.decode([BARTStopTagConfiguration].self, forKey: .stops)
    }
}
