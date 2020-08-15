//
//  FavoritesState.swift
//  Bussr
//
//  Created by jackson on 7/23/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation

class FavoriteState: NSObject
{
    enum FavoritesOrganizeType: Int
    {
        case list
        case stop
        case group
        case addingToGroup
        case route
    }
    
    static var favoritesOrganizeType: FavoritesOrganizeType = .list
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
