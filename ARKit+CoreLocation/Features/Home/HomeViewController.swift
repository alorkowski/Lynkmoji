//
//  HomeViewController.swift
//  ARKit+CoreLocation
//
//  Created by Alexander Lorkowski on 7/28/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseUI
import GeoFire
import SCSDKLoginKit
import VerticalCardSwiper

@available(iOS 11.0, *)
class HomeViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var showMapSwitch: UISwitch!
    @IBOutlet weak var showPointsOfInterest: UISwitch!
    @IBOutlet weak var showRouteDirections: UISwitch!
    @IBOutlet weak var addressText: UITextField!
    @IBOutlet weak var searchResultTable: UITableView!
    @IBOutlet weak var refreshControl: UIActivityIndicatorView!
    @IBOutlet private var cardSwiper: VerticalCardSwiper!

    // MARK: - Stored Properties
    let locationManager = CLLocationManager()
    let homeViewModel = HomeViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self

        cardSwiper.delegate = self
        cardSwiper.datasource = self
        cardSwiper.register(nib: UINib(nibName: "LocationCell", bundle: nil),
                            forCellWithReuseIdentifier: "LocationCell")

        homeViewModel.authUI?.delegate = self
        homeViewModel.authUI?.providers = [FUIPhoneAuth(authUI: FUIAuth.defaultAuthUI()!)]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard homeViewModel.isUserSignedIn else {
            showLoginView()
            return
        }
        homeViewModel.locationSearchStatus = .active
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
        homeViewModel.fetchSnapUserInfo({ (userEntity, _) in
            guard userEntity != nil else { return }
            DispatchQueue.main.async {
                self.navigationController?.setNavigationBarHidden(true, animated: true)
            }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - IBActions
    @IBAction func toggledSwitch(_ sender: UISwitch) {
        if sender == showPointsOfInterest {
            searchResultTable.reloadData()
        }
    }

    @IBAction func tappedSearch(_ sender: Any) {
        guard let text = addressText.text, !text.isEmpty else { return }
        homeViewModel.searchForLocation(coordinate: locationManager.location?.coordinate) { [weak self] in
            self?.cardSwiper.reloadData()
        }
    }
}

// MARK: - FUIAuthDelegate
extension HomeViewController: FUIAuthDelegate {
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        homeViewModel.snapChatLogin(from: self)
    }

    private func showLoginView() {
        if let authVC = FUIAuth.defaultAuthUI()?.authViewController() {
            present(authVC, animated: true, completion: nil)
        }
    }
}

// MARK: - Implementation
@available(iOS 11.0, *)
extension HomeViewController {
    func createARVC() -> POIViewController {
        let arclVC = POIViewController.loadFromStoryboard()
        arclVC.showMap = true //showMapSwitch.isOn
        return arclVC
    }

    func getDirections(to mapLocation: MatchlessMKMapItem) {
        refreshControl.startAnimating()
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapLocation
        request.requestsAlternateRoutes = true

        MKDirections(request: request).calculate { response, error in
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
                guard let `self` = self else { return }
                let arclVC = self.createARVC()
                arclVC.routes = response.routes
                print(response.routes)
                arclVC.memberMKMapItem = mapLocation
                self.navigationController?.pushViewController(arclVC, animated: true)
            }
        }
    }
}

// MARK: - UITextFieldDelegate
@available(iOS 11.0, *)
extension HomeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string == "\n" {
            DispatchQueue.main.async { [weak self] in
                self?.homeViewModel.searchForLocation(coordinate: self?.locationManager.location?.coordinate) {
                    self?.cardSwiper.reloadData()
                }
            }
        }
        return true
    }
}

// MARK: - CLLocationManagerDelegate
@available(iOS 11.0, *)
extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate else { return }
        homeViewModel.updateUserLocation(coordinate: coordinate) { [weak self] in
            self?.cardSwiper.reloadData()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: // If status has not yet been determied, ask for authorization
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: // If authorized when in use
            manager.startUpdatingLocation()
        case .authorizedAlways: // If always authorized
            manager.startUpdatingLocation()
        case .restricted: // If restricted by e.g. parental controls. User can't enable Location Services
            break
        case .denied: // If user denied your app access to Location Services, but can grant access from Settings.app
            break
        default:
            break
        }
    }
}

// MARK: - VerticalCardSwiperDatasource
extension HomeViewController: VerticalCardSwiperDatasource {
    func cardForItemAt(verticalCardSwiperView: VerticalCardSwiperView,
                       cardForItemAt index: Int) -> CardCell {
        guard let cardCell = verticalCardSwiperView.dequeueReusableCell(withReuseIdentifier: "LocationCell", for: index) as? LocationCell else { return CardCell() }
        cardCell.locationManager = locationManager
        cardCell.mapItem = homeViewModel.mapSearchResults[index]
        return cardCell
    }

    func numberOfCards(verticalCardSwiperView: VerticalCardSwiperView) -> Int {
        return homeViewModel.mapSearchResults.count
    }
}

// MARK: - VerticalCardSwiperDelegate
extension HomeViewController: VerticalCardSwiperDelegate {
    func didSwipeCardAway(card: CardCell, index: Int, swipeDirection: SwipeDirection) {
        homeViewModel.mapSearchResults.remove(at: index)
    }

    func didTapCard(verticalCardSwiperView: VerticalCardSwiperView, index: Int) {
        if homeViewModel.heldIndex != index {
            homeViewModel.heldIndex = index
            homeViewModel.selectedMapItem = homeViewModel.mapSearchResults[index] as MatchlessMKMapItem
            getDirections(to: homeViewModel.selectedMapItem!)
        }
    }
}
