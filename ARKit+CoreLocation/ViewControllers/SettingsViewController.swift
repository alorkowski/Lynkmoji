//
//  SettingsViewController.swift
//  ARKit+CoreLocation
//
//  Created by Eric Internicola on 2/19/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import CoreLocation
import MapKit
import GeoFire
import Firebase
import FirebaseDatabase
import FirebaseAuth
import UIKit
import VerticalCardSwiper
import SCSDKLoginKit
import FirebaseUI

enum LocationSearchStatus {
    case active
    case off
}

@available(iOS 11.0, *)
class SettingsViewController: UIViewController, FUIAuthDelegate {
    @IBOutlet weak var showMapSwitch: UISwitch!
    @IBOutlet weak var showPointsOfInterest: UISwitch!
    @IBOutlet weak var showRouteDirections: UISwitch!
    @IBOutlet weak var addressText: UITextField!
    @IBOutlet weak var searchResultTable: UITableView!
    @IBOutlet weak var refreshControl: UIActivityIndicatorView!
    @IBOutlet private var cardSwiper: VerticalCardSwiper!

    let locationManager = CLLocationManager()
    var mapSearchResults = [MatchlessMKMapItem]()
    var selectedMapItem: MatchlessMKMapItem?
    var heldIndex: Int? = -1
    var geoFireRef: DatabaseReference?
    var geoFire: GeoFire?
    var myQuery: GFQuery?
    let authUI: FUIAuth? = FUIAuth.defaultAuthUI()
    var locationSearchStatus = LocationSearchStatus.active

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self

        // addressText.delegate = self

        geoFireRef = Database.database().reference().child("users")
        geoFire = GeoFire(firebaseRef: geoFireRef!)
        cardSwiper.delegate = self
        cardSwiper.datasource = self

        // register cardcell for storyboard use
        cardSwiper.register(nib: UINib(nibName: "LocationCell", bundle: nil),
                            forCellWithReuseIdentifier: "LocationCell")
        // You need to adopt a FUIAuthDelegate protocol to receive callback
        authUI!.delegate = self

        let providers: [FUIAuthProvider] = [
            FUIPhoneAuth(authUI: FUIAuth.defaultAuthUI()!),
        ]
        //self.authUI.providers = providers
    }

    private func isUserSignedIn() -> Bool {
        guard Auth.auth().currentUser != nil else { return false }
        return true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        locationSearchStatus = .active
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()

        //self.fetchSnapUserInfo({ (userEntity, error) in
        //
        //if let userEntity = userEntity {
        //DispatchQueue.main.async {
        //self.navigationController?.setNavigationBarHidden(true, animated: true)
        //
        //}
        //}
        //})

        //let phoneProvider = FUIAuth.defaultAuthUI()!.providers.first as! FUIPhoneAuth
        //phoneProvider.signIn(withPresenting: self, phoneNumber: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    private func showLoginView() {
        if let authVC = FUIAuth.defaultAuthUI()?.authViewController() {
            present(authVC, animated: true, completion: nil)
        }
    }

    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        print("signed in")
        //snapChatLogin()
    }

    private func snapChatLogin() {
        SCSDKLoginClient.login(from: self, completion: { success, error in
            if let error = error {
                print("error shit!")
                print(error.localizedDescription)
                return
            }
            print("here")
            if success {
                self.fetchSnapUserInfo { [weak self] (userEntity, _) in
                    guard userEntity != nil else { return }
                    self?.searchForLocation()
                }
            }
        })
    }

    private func fetchSnapUserInfo(_ completion: @escaping ((UserEntity?, Error?) -> Void)) {
        let graphQLQuery = "{me{externalId, displayName, bitmoji{avatar}}}"
        print("fetching")
        SCSDKLoginClient
            .fetchUserData( withQuery: graphQLQuery,
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
                                completion(nil, error)
            }
        )
    }

    @IBAction func toggledSwitch(_ sender: UISwitch) {
        if sender == showPointsOfInterest {
            //showRouteDirections.isOn = !sender.isOn
            searchResultTable.reloadData()
        } else if sender == showRouteDirections {
            //showPointsOfInterest.isOn = !sender.isOn
            //searchResultTable.reloadData()
        }
    }

    @IBAction func tappedSearch(_ sender: Any) {
        guard let text = addressText.text, !text.isEmpty else { return }
        searchForLocation()
    }
}

// MARK: - UITextFieldDelegate
@available(iOS 11.0, *)
extension SettingsViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string == "\n" {
            DispatchQueue.main.async { [weak self] in
                self?.searchForLocation()
            }
        }
        return true
    }
}

// MARK: - CLLocationManagerDelegate
@available(iOS 11.0, *)
extension SettingsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard case LocationSearchStatus.active = locationSearchStatus,
            let location = locations.first else { return }

        DispatchQueue.main.async {
            let location: CLLocation = CLLocation(latitude: CLLocationDegrees(location.coordinate.latitude),
                                                  longitude: CLLocationDegrees(location.coordinate.longitude))
            self.geoFire?.setLocation(location, forKey: Auth.auth().currentUser!.uid)
            self.searchForLocation()
        }

        locationSearchStatus = .off
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            // If status has not yet been determied, ask for authorization
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // If authorized when in use
            manager.startUpdatingLocation()
        case .authorizedAlways:
            // If always authorized
            manager.startUpdatingLocation()
        case .restricted:
            // If restricted by e.g. parental controls. User can't enable Location Services
            break
        case .denied:
            // If user denied your app access to Location Services, but can grant access from Settings.app
            break
        default:
            break
        }
    }
}

// MARK: - Implementation
@available(iOS 11.0, *)
extension SettingsViewController {
    func createARVC() -> POIViewController {
        let arclVC = POIViewController.loadFromStoryboard()
        arclVC.showMap = true //showMapSwitch.isOn
        return arclVC
    }

    func getDirections(to mapLocation: MatchlessMKMapItem) {
        refreshControl.startAnimating()

        print("getting directions")

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapLocation
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)

        directions.calculate(completionHandler: { response, error in
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.refreshControl.stopAnimating()
                }
            }
            if let error = error {
                return print("Error getting directions: \(error.localizedDescription)")
            }
            guard let response = response else {
                return assertionFailure("No error, but no response, either.")
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }

                let arclVC = self.createARVC()
                arclVC.routes = response.routes
                print(response.routes)
                arclVC.memberMKMapItem = mapLocation
                self.navigationController?.pushViewController(arclVC, animated: true)
            }
        })
    }

    /// Searches for the location that was entered into the address text
    func searchForLocation() {
        print("search")
        myQuery = geoFire?.query(at: CLLocation(coordinate: self.locationManager.location!.coordinate,
                                                altitude: 0.5),
                                 withRadius: 1000)

        myQuery?.observe(.keyEntered, with: { (key, location) in
            Database.database().reference().child("users").child(key).observe(.value, with: { (snapshot) in
                let userDict = snapshot.value as? [String: AnyObject] ?? [:]
                //if (userDict["active"]! as! String != "false") {
                // swiftlint:disable:next force_cast
                let snap_info = userDict["snap_info"] as! [String: AnyObject]
                // swiftlint:disable:next force_cast
                let destination = MatchlessMKMapItem(coordinate: location.coordinate, profileFileURL: snap_info["bitmoji_url"] as! String)
                //destination.name = "test"
                self.mapSearchResults.append(destination)
                self.cardSwiper.reloadData()
                print("here")
            })
            //self.resetARScene()
        })
    }
}

extension MKLocalSearch.Response {
    func sortedMapItems(byDistanceFrom location: CLLocation?) -> [MKMapItem] {
        guard let location = location else {
            return mapItems
        }

        return mapItems.sorted { (first, second) -> Bool in
            guard let d1 = first.placemark.location?.distance(from: location),
                let d2 = second.placemark.location?.distance(from: location) else {
                    return true
            }
            return d1 < d2
        }
    }
}

extension SettingsViewController: VerticalCardSwiperDatasource {
    func cardForItemAt(verticalCardSwiperView: VerticalCardSwiperView,
                       cardForItemAt index: Int) -> CardCell {
        if let cardCell = verticalCardSwiperView.dequeueReusableCell(withReuseIdentifier: "LocationCell",
                                                                     for: index) as? LocationCell {
            cardCell.locationManager = locationManager
            cardCell.mapItem = mapSearchResults[index]
            return cardCell
        }
        return CardCell()
    }

    func numberOfCards(verticalCardSwiperView: VerticalCardSwiperView) -> Int {
        return mapSearchResults.count
    }
}

extension SettingsViewController: VerticalCardSwiperDelegate {
    func willSwipeCardAway(card: CardCell, index: Int, swipeDirection: SwipeDirection) {
        // called right before the card animates off the screen.
    }

    func didSwipeCardAway(card: CardCell, index: Int, swipeDirection: SwipeDirection) {
        //if swipeDirection == .Right {
        //selectedMapItem = mapSearchResults[index] as MatchlessMKMapItem
        //getDirections(to: selectedMapItem!)
        //}
        mapSearchResults.remove(at: index)
    }

    func didTapCard(verticalCardSwiperView: VerticalCardSwiperView, index: Int) {
        if heldIndex != index {
            heldIndex = index
            selectedMapItem = mapSearchResults[index] as MatchlessMKMapItem
            getDirections(to: selectedMapItem!)
        }
    }

    func didHoldCard(verticalCardSwiperView: VerticalCardSwiperView, index: Int, state: UIGestureRecognizer.State) {
        //if heldIndex != index {
        //heldIndex = index
        //selectedMapItem = mapSearchResults[index] as MatchlessMKMapItem
        //getDirections(to: selectedMapItem!)
        //}
    }
}
