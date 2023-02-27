//
//  AgencyConfiguration.swift
//  Bussr
//
//  Created by jackson on 11/17/22.
//  Copyright © 2022 jackson. All rights reserved.
//

import Foundation

struct UmoIQAgency: Codable
{
    let tag: String
    let name: String
    let revision: Int

    enum CodingKeys: String, CodingKey
    {
        case tag = "id"
        case name
        case revision = "rev"
    }
}
