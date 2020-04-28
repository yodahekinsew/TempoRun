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
    
    public var boseAccelerationData: [(x: Float, y: Float, z: Float)] = []
    public var boseGyroData: [(x: Float, y: Float, z: Float)] = []
    public var boseRotationData: [(x: Float, y: Float, z: Float, w: Float)] = []
    
    private var sensors = [
        "accelerometer",
        "gyroscope",
        "rotation",
        "gameRotation",
        "orientation",
        "magnetometer",
        "uncalibratedMagnetometer",
    ]
    private var gestures = [
        "singleTap",
        "doubleTap",
        "headNod",
        "headShake",
    ]
    private var sensorOffset = 0
    private var gestureOffset = 128
    private var possibleSamplePeriods = [
        320,
        160,
        80,
        40,
        20
    ]
    private var accuracies = [
        "unreliable",
        "low",
        "medium",
        "high"
    ]
    
    func getSensor(using sensorID: UInt) -> String {
        return sensors[Int(sensorID)]
    }
    
    func parseSensorInformation(using sensorInformationCharacteristic: CBCharacteristic) -> Data {
        print("---- Sensor Information ----")
        let length = 12
        var offset = 0
        if let value = sensorInformationCharacteristic.value {
            while(offset + length <= value.count) {
                let sensorID = UInt8(value[offset])
                let minScaled = UInt16(value[offset+1]) << 8 | UInt16(value[offset+2])
                let maxScaled = UInt16(value[offset+3]) << 8 | UInt16(value[offset+4])
                let minRaw = UInt16(value[offset+5]) << 8 | UInt16(value[offset+6])
                let maxRaw = UInt16(value[offset+7]) << 8 | UInt16(value[offset+8])
                let samplePeriodBitmask = UInt16(value[offset+9]) << 8 | UInt16(value[offset+10])
                let sampleLength = UInt8(value[offset+11])
                print("Sensor Information Entry: \(sensorID) \(minScaled) \(maxScaled) \(minRaw) \(maxRaw) \(samplePeriodBitmask) \(sampleLength)")
                offset += length
            }
            return value
        }
        return Data()
    }
    
    func parseSensorConfiguration(using sensorConfigurationCharacteristic: CBCharacteristic) -> Data {
        print("---- Sensor Configuration ----")
        let length = 3
        var offset = 0
        if let value = sensorConfigurationCharacteristic.value {
            while(offset + length <= value.count) {
                let sensorID = UInt8(value[offset])
                let samplePeriod = UInt16(value[offset+1]) << 8 | UInt16(value[offset+2])
                print("Sensor Configuration Entry: \(sensorID) \(samplePeriod)")
                offset += length
            }
            return value
        }
        return Data()
    }
    
    func parseSensorData(using sensorDataCharacteristic: CBCharacteristic) -> Data {
//        print("---- Sensor Data ----")
        let headerLength = 3
        var offset = 0
        if let value = sensorDataCharacteristic.value {
            while (offset < value.count) {
                let sensorID = UInt8(value[offset])
                let timestamp = UInt16(value[offset+1]) << 8 | UInt16(value[offset+2])
                offset += headerLength
                switch(sensorID) {
                case 0:
                    let denominator = Float(pow(2.0, 12.0)) //Divide by denominator to get value in terms of "gs"
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
//                    let accuracy = UInt8(value[offset+6])
                    boseAccelerationData.append((x,y,z))
                    offset += 7
//                    print("Accelerometer Data: x - \(Double(x)/denominator), y - \(Double(y)/denominator), z - \(Double(z)/denominator)")
                case 1:
                    let x = Float(UInt16(value[offset]) << 8 | UInt16(value[offset+1]))
                    let y = Float(UInt16(value[offset+2]) << 8 | UInt16(value[offset+3]))
                    let z = Float(UInt16(value[offset+4]) << 8 | UInt16(value[offset+5]))
//                    let accuracy = UInt8(value[offset+6])
                    boseGyroData.append((x,y,z))
                    offset += 7
//                    print("Gyroscope Data: \(sensorID) \(timestamp) \(x) \(y) \(z) \(accuracy)")
                case 2:
                    let x = Float(UInt16(value[offset]) << 8 | UInt16(value[offset+1]))
                    let y = Float(UInt16(value[offset+2]) << 8 | UInt16(value[offset+3]))
                    let z = Float(UInt16(value[offset+4]) << 8 | UInt16(value[offset+5]))
                    let w = Float(UInt16(value[offset+6]) << 8 | UInt16(value[offset+7]))
//                    let accuracy = UInt16(value[offset+8]) << 8 | UInt16(value[offset+9])
                    boseRotationData.append((x,y,z,w))
                    offset += 10
//                    print("Rotation Data: \(sensorID) \(timestamp) \(x) \(y) \(z) \(w) \(accuracy)")
                case 3:
//                    let x = UInt16(value[offset]) << 8 | UInt16(value[offset+1])
//                    let y = UInt16(value[offset+2]) << 8 | UInt16(value[offset+3])
//                    let z = UInt16(value[offset+4]) << 8 | UInt16(value[offset+5])
//                    let w = UInt16(value[offset+6]) << 8 | UInt16(value[offset+7])
                    offset += 8
//                    print("Game Rotation Data: \(sensorID) \(timestamp) \(x) \(y) \(z) \(w)")
                default:
                    print("Unsupported sensor \(sensorID)")
                }
            }
            return value
        }
        return Data()
    }
    
    func parseGestureConfiguration(using sensorDataCharacteristic: CBCharacteristic) -> Data {
        return Data()
    }
    
    func parseGestureInformation(using sensorDataCharacteristic: CBCharacteristic) -> Data {
        return Data()
    }
    
    func parseGestureData(using sensorDataCharacteristic: CBCharacteristic) -> Data {
        return Data()
    }
    
}
