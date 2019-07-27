//
//  ATCClassicWalkthroughViewController.swift
//  ARKit+CoreLocation
//
//  Created by Daniel Golman on 7/5/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import UIKit
import SCSDKLoginKit
import Firebase
import FirebaseDatabase
import FirebaseAuth
import GeoFire

class ATCClassicWalkthroughViewController: UIViewController {
    @IBOutlet var containerView: UIView!
    @IBOutlet var imageContainerView: UIView!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    var geoFireRef: DatabaseReference?
    var geoFire: GeoFire?
    
    @IBAction func registerButtonTapped(_ sender: Any) {
        self.goToSettingsViewController()
    }
    
    private func goToSettingsViewController(){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
    }
    
    let model: ATCWalkthroughModel
    
    init(model: ATCWalkthroughModel,
         nibName nibNameOrNil: String?,
         bundle nibBundleOrNil: Bundle?) {
        self.model = model
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        imageView.image = UIImage.localImage(model.icon, template: true)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.tintColor = .white
        imageContainerView.backgroundColor = .clear
        
        titleLabel.text = model.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20.0)
        titleLabel.textColor = .white
        
        subtitleLabel.attributedText = NSAttributedString(string: model.subtitle)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14.0)
        subtitleLabel.textColor = .white
        
        containerView.backgroundColor = UIColor(hexString: "#000000")
        
        geoFireRef = Database.database().reference().child("users")
        geoFire = GeoFire(firebaseRef: geoFireRef!)
    }
}
