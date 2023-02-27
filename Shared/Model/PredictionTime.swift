//
//  PredictionTime.swift
//  Bussr
//
//  Created by jackson on 11/17/22.
//  Copyright © 2022 jackson. All rights reserved.
//

import Foundation

enum PredictionTimeType
{
    case exact
    case schedule
}

protocol PredictionTime: Codable
{
    var time: String { get set }
    var vehicleID: String? { get set }
    var type: PredictionTimeType { get set }
}

enum PredictionTimeFetchResult
{
    case success(predictions: Array<PredictionTime>)
    case error(reason: String)
}

protocol VehicleLocation: Codable
{
    var vehicleID: String { get set }
    var latitude: Double { get set }
    var longitude: Double { get set }
    var heading: Int? { get set }
}

enum VehicleLocationFetchResult
{
    case success(vehicleLocations: Array<VehicleLocation>)
    case error(reason: String)
}

class UmoIQRouteStopPredictionContainer: Codable
{
    var predictions: Array<UmoIQPredictionTime>
    
    enum CodingKeys: String, CodingKey
    {
        case predictions = "values"
    }
}

class UmoIQPredictionTime: PredictionTime
{
    var time: String
    var vehicleID: String?
    var type: PredictionTimeType = .exact
    
    enum CodingKeys: String, CodingKey
    {
        case time = "minutes"
        case vehicleID
    }
}

class UmoIQRouteVehicleLocation: VehicleLocation
{
    var vehicleID: String
    var latitude: Double
    var longitude: Double
    var heading: Int?
    
    enum CodingKeys: String, CodingKey
    {
        case vehicleID = "id"
        case latitude = "lat"
        case longitude = "lon"
        case heading
    }
}

class BARTPredictionContainer: Codable
{
    var routes: Array<BARTRoutePredictions>
    
    enum RootCodingKeys: String, CodingKey
    {
        case root
    }
    
    enum StationCodingKeys: String, CodingKey
    {
        case station
    }
    
    enum RoutesCodingKeys: String, CodingKey
    {
        case routes = "etd"
    }
    
    required init(from decoder: Decoder) throws
    {
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        let baseStationsContainer = try rootContainer.nestedContainer(keyedBy: StationCodingKeys.self, forKey: .root)
        let baseStationContainer = try baseStationsContainer.nestedContainer(keyedBy: RoutesCodingKeys.self, forKey: .station)
        
        self.routes = try baseStationContainer.decode([BARTRoutePredictions].self, forKey: .routes)
    }
}

class BARTRoutePredictions: Codable
{
    var predictions: Array<BARTPredictionTime>
    var abbreviation: String
    
    enum CodingKeys: String, CodingKey
    {
        case predictions = "estimate"
        case abbreviation
    }
}

class BARTPredictionTime: PredictionTime
{
    var time: String
    var vehicleID: String? = nil
    var type: PredictionTimeType = .exact
    
    var hexColor: String
    
    enum CodingKeys: String, CodingKey
    {
        case time = "minutes"
        case hexColor = "hexcolor"
    }
}
