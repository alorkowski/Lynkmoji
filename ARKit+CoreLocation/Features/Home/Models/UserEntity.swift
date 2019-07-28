//
//  UserEntity.swift
//  ARKit+CoreLocation
//
//  Created by Daniel Golman on 7/5/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import Foundation
import MapKit

struct UserEntity {
    let displayName: String?
    let avatar: String?
    let externalId: String?
    var location: CLLocation

    private enum CodingKeys: String, CodingKey {
        case data
    }

    private enum DataKeys: String, CodingKey {
        case me
    }

    private enum MeKeys: String, CodingKey {
        case displayName
        case bitmoji
        case externalId
    }

    private enum BitmojiKeys: String, CodingKey {
        case avatar
    }
}

extension UserEntity: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let data = try values.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        let me = try data.nestedContainer(keyedBy: MeKeys.self, forKey: .me)

        displayName = try? me.decode(String.self, forKey: .displayName)

        let bitmoji = try me.nestedContainer(keyedBy: BitmojiKeys.self, forKey: .bitmoji)
        avatar = try? bitmoji.decode(String.self, forKey: .avatar)

        externalId = try? me.decode(String.self, forKey: .externalId)

        location = CLLocation(latitude: 37.7596, longitude: 122.4269)
    }
}
