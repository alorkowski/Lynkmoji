//
//  File.swift
//  ARKit+CoreLocation
//
//  Created by Daniel Golman on 7/2/19.
//  Copyright © 2019 Project Dent. All rights reserved.
//

import Foundation
import MapKit

open class MatchlessMKMapItem: MKMapItem {
    
//    var coordinate = CLLocationCoordinate2D()
    var profileImage: UIImage?
    
    init(coordinate: CLLocationCoordinate2D, profileFileURL: String) {
        
        var place: MKPlacemark!
        
        if #available(iOS 10.0, *) {
            place = MKPlacemark(coordinate: coordinate)
        } else {
            place = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        }
        
        super.init(placemark: place)
//        self.coordinate = coordinate
        do {
            let url = URL(string: profileFileURL)!
            let data = try Data(contentsOf: url)
            self.profileImage = UIImage(data: data, scale: 3)
        }
        catch {
            //            bitmojiImage = SCSDKBitmojiIconView().defaultImage
        }
       
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
