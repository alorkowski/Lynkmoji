//
//  LandingViewModel.swift
//  ARKit+CoreLocation
//
//  Created by Alexander Lorkowski on 7/27/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import Foundation
import FirebaseAuth
import SCSDKLoginKit
import Firebase
import FirebaseDatabase
import GeoFire

class LandingViewModel {
    // MARK: - Stored Properties
    private var geoFireRef: DatabaseReference?
    private var geoFire: GeoFire?
    let walkthroughs = [
        ATCWalkthroughModel(title: "Welcome to Matchless",
                            subtitle: "Offline Dating",
                            icon: "activity-feed-icon"),
        ATCWalkthroughModel(title: "No Swiping",
                            subtitle: "See all your matches in real-time by scanning a user in front of you",
                            icon: "analytics-icon"),
        ATCWalkthroughModel(title: "Verificaton",
                            subtitle: "Everyone is verified for safety. Yes, this is anonymous, and we will keep you protected",
                            icon: "bars-icon"),
        ATCWalkthroughModel(title: "Get Notified",
                            subtitle: "Receive notifications when people that are nearby and want to match.",
                            icon: "bell-icon")
    ]

    // MARK: - Computed Properties
    var isUserSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
}

// MARK: - Functions
extension LandingViewModel {
    func setupGeoFire() {
        geoFireRef = Database.database().reference().child("users")
        geoFire = GeoFire(firebaseRef: geoFireRef!)
    }

    func fetchSnapUserInfo(_ completion: @escaping ((UserEntity?, Error?) -> Void)) {
        let graphQLQuery = "{me{externalId, displayName, bitmoji{avatar}}}"
        SCSDKLoginClient
            .fetchUserData(
                withQuery: graphQLQuery,
                variables: nil,
                success: { userInfo in
                    if let userInfo = userInfo,
                        let data = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted),
                        let userEntity = try? JSONDecoder().decode(UserEntity.self, from: data) {
                        var dictionary = [String: String]()
                        dictionary["bitmoji_url"] = userEntity.avatar
                        dictionary["display_name"] = userEntity.displayName
                        print("storing")
                        self.geoFireRef?.child(Auth.auth().currentUser!.uid).child("snap_info").setValue(dictionary)
                        completion(userEntity, nil)
                    }},
                failure: { (error, _) in
                    completion(nil, error) }
        )
    }
}
