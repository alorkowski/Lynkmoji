//
//  HomeViewModel.swift
//  ARKit+CoreLocation
//
//  Created by Alexander Lorkowski on 7/28/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import GeoFire
import Firebase
import FirebaseDatabase
import FirebaseAuth
import VerticalCardSwiper
import SCSDKLoginKit
import FirebaseUI

enum LocationSearchStatus {
    case active
    case off
}

class HomeViewModel {
    // MARK: - Stored Porperties
    var mapSearchResults = [MatchlessMKMapItem]()
    var selectedMapItem: MatchlessMKMapItem?
    var heldIndex: Int? = -1
    var geoFireRef: DatabaseReference?
    var geoFire: GeoFire?
    var myQuery: GFQuery?
    let authUI: FUIAuth? = FUIAuth.defaultAuthUI()
    var locationSearchStatus = LocationSearchStatus.active

    // MARK: - Computed Properties
    var isUserSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }

    // MARK: - Initializers
    init() {
        geoFireRef = Database.database().reference().child("users")
        geoFire = GeoFire(firebaseRef: geoFireRef!)
    }
}

// MARK: - SnapChat
extension HomeViewModel {
    func snapChatLogin(from view: UIViewController) {
        SCSDKLoginClient.login(from: view, completion: { success, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            if success {
                self.fetchSnapUserInfo { [weak self] (userEntity, _) in
                    guard userEntity != nil else { return }
                    self?.searchForLocation(coordinate: nil, completionHandler: nil)
                }
            }
        })
    }

    func fetchSnapUserInfo(_ completion: @escaping ((UserEntity?, Error?) -> Void)) {
        let graphQLQuery = "{me{externalId, displayName, bitmoji{avatar}}}"
        print("fetching")
        SCSDKLoginClient
            .fetchUserData( withQuery: graphQLQuery,
                            variables: nil,
                            success: { [weak self] userInfo in
                                guard let userInfo = userInfo,
                                    let data = try? JSONSerialization.data(withJSONObject: userInfo,
                                                                           options: .prettyPrinted),
                                    let userEntity = try? JSONDecoder().decode(UserEntity.self,
                                                                               from: data)
                                    else { return }
                                var dictionary = [String: String]()
                                dictionary["bitmoji_url"] = userEntity.avatar
                                dictionary["display_name"] = userEntity.displayName
                                self?.geoFireRef?
                                    .child(Auth.auth().currentUser!.uid)
                                    .child("snap_info")
                                    .setValue(dictionary)
                                completion(userEntity, nil) },
                            failure: { (error, _) in
                                completion(nil, error) }
        )
    }
}

extension HomeViewModel {
    /// Searches for the location that was entered into the address text
    func searchForLocation(coordinate: CLLocationCoordinate2D?, completionHandler: (() -> Void)?) {
        guard let coordinate = coordinate else { return }
        myQuery = geoFire?.query(at: CLLocation(coordinate: coordinate,
                                                altitude: 0.5),
                                 withRadius: 1000)
        myQuery?.observe(.keyEntered, with: { (key, location) in
            Database.database().reference().child("users").child(key).observe(.value, with: { (snapshot) in
                let userDict = snapshot.value as? [String: AnyObject] ?? [:]
                guard let snap_info = userDict["snap_info"] as? [String: AnyObject],
                    let profileURL = snap_info["bitmoji_url"] as? String else { return }
                let destination = MatchlessMKMapItem(coordinate: location.coordinate,
                                                     profileFileURL: profileURL)
                self.mapSearchResults.append(destination)
            })
        })
        completionHandler?()
    }

    func updateUserLocation(coordinate: CLLocationCoordinate2D?, completionHandler: (() -> Void)?) {
        guard case LocationSearchStatus.active = locationSearchStatus,
            let currentUser = Auth.auth().currentUser,
            let coordinate = coordinate else { return }

        DispatchQueue.main.async {
            let location: CLLocation = CLLocation(latitude: CLLocationDegrees(coordinate.latitude),
                                                  longitude: CLLocationDegrees(coordinate.longitude))
            self.geoFire?.setLocation(location, forKey: currentUser.uid)
            self.searchForLocation(coordinate: coordinate, completionHandler: completionHandler)
        }

        locationSearchStatus = .off
    }
}

extension MKLocalSearch.Response {
    func sortedMapItems(byDistanceFrom location: CLLocation?) -> [MKMapItem] {
        guard let location = location else { return mapItems }
        return mapItems.sorted { (first, second) -> Bool in
            guard let d1 = first.placemark.location?.distance(from: location),
                let d2 = second.placemark.location?.distance(from: location) else {
                    return true
            }
            return d1 < d2
        }
    }
}
