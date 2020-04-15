//
//  BoseFramesPeripheral.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/15/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class BoseFramesPeripheral: NSObject {

    /// MARK: - Particle LED services and charcteristics Identifiers
    public static let boseServiceUUID = CBUUID.init(string: "0000fdd2-0000-1000-8000-00805f9b34fb")
    
    public static let boseFramesUUID = CBUUID.init(string: "7b61ad83-041c-4333-a0ab-efb2ab7bdd43")
    
    public static let sensorInformationUUID = CBUUID.init(string: "855cb3e7-98ff-42a6-80fc-40b32a2221c1")
    public static let sensorConfigurationUUID = CBUUID.init(string: "5af38af6-000e-404b-9b46-07f77580890b")
    public static let sensorDataUUID = CBUUID.init(string: "56a72ab8-4988-4cc8-a752-fbd1d54a953d")
    
    public static let gestureInformationUUID = CBUUID.init(string: "a0384f52-f95a-4bcd-b898-7b9ceec92dad")
    public static let gestureConfigurationUUID = CBUUID.init(string: "21e550af-f780-477b-9334-1f983296f1d7")
    public static let gestureDataUUID = CBUUID.init(string: "9014dd4e-79ba-4802-a275-894d3b85ac74")
}
