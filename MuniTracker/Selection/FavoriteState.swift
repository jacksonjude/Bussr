//
//  FavoritesState.swift
//  MuniTracker
//
//  Created by jackson on 7/23/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation

class FavoriteState: NSObject
{
    enum FavoritesOrganizeType: Int
    {
        case route
        case stop
        case list
        case group
        case addingToGroup
    }
    
    static var favoritesOrganizeType: FavoritesOrganizeType = .route
    {
        didSet
        {
            UserDefaults.standard.set(favoritesOrganizeType.rawValue, forKey: "FavoritesOrganizeType")
        }
    }
    static var favoriteObject: Any?
    static var selectedRouteTag: String?
    static var selectedGroupUUID: String?
}
