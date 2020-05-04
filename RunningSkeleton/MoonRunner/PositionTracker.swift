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
  
    public var speedState = "constant"
    
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
        let previousCurrentVelocity = currentVelocity
        currentVelocity = (
          x: currentVelocity.x + 9.8*(currentAcceleration.x - sinf(Float.pi-currentHeading.pitch))*0.02,
          y: currentVelocity.y + 9.8*currentAcceleration.y*0.02,
          z: currentVelocity.z + 9.8*currentAcceleration.z*0.02
        )
        if (currentVelocity.x > previousCurrentVelocity.x + 0.2
          || currentVelocity.y > previousCurrentVelocity.y + 0.2) {
          speedState = "increasing";
        } else if (currentVelocity.x < previousCurrentVelocity.x - 0.2
          || currentVelocity.y < previousCurrentVelocity.y - 0.2) {
          speedState = "decreasing";
        } else {
          speedState = "constant";
        }
        let deltaPosition = currentVelocity.x*0.02
        let deltaY = deltaPosition*cosf(currentHeading.yaw)
        let deltaX = deltaPosition*sinf(currentHeading.yaw)
        let deltaLongitude = deltaY/111111
        let deltaLatitude = deltaX/(111111*cosf(Float(currentGPSPosition!.longitude)))
        currentGPSPosition!.longitude = Double(deltaLongitude)
        currentGPSPosition!.latitude = Double(deltaLatitude)
    }
}
