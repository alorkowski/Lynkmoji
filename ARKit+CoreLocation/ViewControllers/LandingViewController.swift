//
//  LandingViewController.swift
//  ARKit+CoreLocation
//
//  Created by Daniel Golman on 7/5/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import UIKit
import FirebaseAuth
import SCSDKLoginKit
import Firebase
import FirebaseDatabase
import GeoFire

class LandingViewController: UIViewController, ATCWalkthroughViewControllerDelegate {
    var geoFireRef: DatabaseReference?
    var geoFire: GeoFire?
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        geoFireRef = Database.database().reference().child("users")
        geoFire = GeoFire(firebaseRef: geoFireRef!)
        if isUserSignedIn() {
            self.fetchSnapUserInfo({ (userEntity, error) in
                guard let _ = userEntity else { return }
                DispatchQueue.main.async {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
                    self.present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
                }
            })
        } else {
            DispatchQueue.main.async {
                let walkthroughVC = self.walkthroughVC()
                walkthroughVC.delegate = self
                self.addChildViewControllerWithView(walkthroughVC)
            }
        }
    }

    private func fetchSnapUserInfo(_ completion: @escaping ((UserEntity?, Error?) -> ())) {
        let graphQLQuery = "{me{externalId, displayName, bitmoji{avatar}}}"
        print("fetching")
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
                    }
            }) { (error, isUserLoggedOut) in
                completion(nil, error)
        }
    }

    private func isUserSignedIn() -> Bool {
        guard Auth.auth().currentUser != nil else { return false }
        return true
    }

    func walkthroughViewControllerDidFinishFlow(_ vc: ATCWalkthroughViewController) {
        UIView.transition(with: self.view, duration: 1, options: .transitionFlipFromLeft, animations: {
            vc.view.removeFromSuperview()
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
            appDelegate?.window?.rootViewController = vc
        }, completion: nil)
    }

    fileprivate func walkthroughVC() -> ATCWalkthroughViewController {
        let viewControllers = walkthroughs.map { ATCClassicWalkthroughViewController(model: $0, nibName: "ATCClassicWalkthroughViewController", bundle: nil) }
        return ATCWalkthroughViewController(nibName: "ATCWalkthroughViewController",
                                            bundle: nil,
                                            viewControllers: viewControllers)
    }
}
