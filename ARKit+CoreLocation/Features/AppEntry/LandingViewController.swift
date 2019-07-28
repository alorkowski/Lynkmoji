//
//  LandingViewController.swift
//  ARKit+CoreLocation
//
//  Created by Daniel Golman on 7/5/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import UIKit

class LandingViewController: UIViewController, ATCWalkthroughViewControllerDelegate {
    // MARK: - Stored Properties
    let landingViewModel = LandingViewModel()

    // TODO: Do we have to do this every time the screen appears? Seems safer to call viewDidLoad()
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        landingViewModel.setupGeoFire()
        if landingViewModel.isUserSignedIn {
            landingViewModel.fetchSnapUserInfo({ (userEntity, _) in
                guard userEntity != nil else { return }
                DispatchQueue.main.async {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    guard let vc = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController else { return }
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

    func walkthroughViewControllerDidFinishFlow(_ vc: ATCWalkthroughViewController) {
        let walkthroughAnimation: (() -> Void)? = {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let vc = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController
            appDelegate?.window?.rootViewController = vc
        }

        UIView.transition(with: self.view,
                          duration: 1,
                          options: .transitionFlipFromLeft,
                          animations: walkthroughAnimation,
                          completion: nil)
    }

    fileprivate func walkthroughVC() -> ATCWalkthroughViewController {
        let viewControllers = landingViewModel.walkthroughs
            .map { ATCClassicWalkthroughViewController(model: $0,
                                                       nibName: "ATCClassicWalkthroughViewController",
                                                       bundle: nil) }
        return ATCWalkthroughViewController(nibName: "ATCWalkthroughViewController",
                                            bundle: nil,
                                            viewControllers: viewControllers)
    }
}
