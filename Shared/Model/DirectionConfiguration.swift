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
    var stopTags: [StopTagConfiguration] { get set }
}

protocol StopTagConfiguration: Decodable
{
    var tag: String { get set }
}

class NextBusDirectionConfiguration: DirectionConfiguration
{
    var title: String
    var tag: String
    var name: String
    
    var stopTags: [StopTagConfiguration]
    
    enum DirectionCodingKeys: String, CodingKey
    {
        case title
        case tag
        case name
        
        case stops = "stop"
    }
    
    class NextBusStopTagConfiguration: StopTagConfiguration
    {
        var tag: String
        
        enum StopTagCodingKeys: String, CodingKey
        {
            case tag
        }
        
        required init(from decoder: Decoder) throws
        {
            let decodedContainer = try decoder.container(keyedBy: StopTagCodingKeys.self)
            
            self.tag = try decodedContainer.decode(String.self, forKey: .tag)
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let decodedContainer = try decoder.container(keyedBy: DirectionCodingKeys.self)
        
        self.title = try decodedContainer.decode(String.self, forKey: .title)
        self.tag = try decodedContainer.decode(String.self, forKey: .tag)
        self.name = try decodedContainer.decode(String.self, forKey: .name)
        
        self.stopTags = try decodedContainer.decode([NextBusStopTagConfiguration].self, forKey: .stops)
    }
}

class BARTDirectionConfiguration: DirectionConfiguration
{
    var title: String
    var tag: String
    var name: String
    
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
        
        let stopConfigContainer = try decodedContainer.nestedContainer(keyedBy: StopsCodingKeys.self, forKey: .stopConfig)
        self.stopTags = try stopConfigContainer.decode([BARTStopTagConfiguration].self, forKey: .stops)
    }
}
