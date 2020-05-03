//
//  PositionTracker.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 5/2/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import Foundation
import CoreLocation

enum LocationAccuracy {
    case Cellular
    case WiFi
    case GPS
}

class PositionTracker: NSObject, CLLocationManagerDelegate {
    private var currentGPSPosition: CLLocationCoordinate2D? = nil
    private var updatedLocation: CLLocationCoordinate2D? = nil
    var locationManager: CLLocationManager? = nil
    
    private var currentVelocity: (x: Float, y: Float, z: Float) = (0,0,0)
    
    func setupLocationManager() {
        self.locationManager = CLLocationManager()
        self.locationManager?.requestAlwaysAuthorization()
        self.locationManager?.delegate = self
        self.locationManager?.distanceFilter = kCLDistanceFilterNone
        self.locationManager?.allowsBackgroundLocationUpdates = true
        self.locationManager?.disallowDeferredLocationUpdates()
        self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startRecordingLocation() {
        self.locationManager?.startUpdatingLocation()
    }
    
    func stopRecordingLocation() {
        self.locationManager?.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for i in 0 ..< locations.count {
            currentGPSPosition = locations[i].coordinate
//            print("Latitude \(currentGPSPosition?.latitude), Longitude \(currentGPSPosition?.longitude)")
        }
    }
    
    func updateWithIMU(acceleration currentAcceleration: (x: Float, y: Float, z: Float), heading currentHeading: (pitch: Float, roll: Float, yaw: Float)) {
        currentVelocity = (
            x: currentVelocity.x + currentAcceleration.x*0.02,
            y: currentVelocity.y + currentAcceleration.y*0.02,
            z: currentVelocity.z + currentAcceleration.z*0.02
        )
        let deltaPosition = currentVelocity.x*0.02
        let deltaY = deltaPosition*cosf(currentHeading.yaw)
        let deltaX = deltaPosiiton*sinf(currentHeading.yaw)
//        change in Y is cos(heading)
//        change in X is sin(heading)
//        var deltaLongitude = 111111*deltaYMeters
//        var deltaLatitude = 111111*cos(longitude)*deltaXMeters
    }
}
