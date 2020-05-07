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
import MediaPlayer
import AVKit


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
    
    private var xAccelOverTime : [Float] = []
    private var yAccelOverTime : [Float] = []
    private var zAccelOverTime : [Float] = []
    public var boseAccelerationData: [(x: Float, y: Float, z: Float)] = []
    public var currentAcceleration : (x: Float, y: Float, z: Float)? = nil
    
    public var boseGyroData: [(x: Float, y: Float, z: Float)] = []
    
    public var currentHeading: (pitch: Float, roll: Float, yaw: Float)? = nil
  
  public var detectedGesture: String = ""

    public var detectedGestureTime: Date = Date()
  
  private var currentVolume : Float = 0.0
  private var audioSession = AVAudioSession.sharedInstance()
    
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
    
    func discretize(num: Float) -> Float {
        return roundf(num*10)/10
    }
    
    func multiplyQuaternions(x: Float, y: Float, z: Float, w: Float, a: Float, b: Float, c: Float, d: Float) -> [Float] {
        var product : [Float] = []
        product.append(x*a-y*b-z*c-w*d)
        return product
    }
    
    func parseSensorData(using sensorDataCharacteristic: CBCharacteristic) -> Data {
        print("---- Sensor Data ----")
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
                    let accuracy = UInt8(value[offset+6])
                    if (boseAccelerationData.count >= 1000) {
                        boseAccelerationData.removeFirst(1)
                    }
                    if (xAccelOverTime.count > 500) {
                        xAccelOverTime.removeFirst(1)
                        yAccelOverTime.removeFirst(1)
                        zAccelOverTime.removeFirst(1)
                    }
                    xAccelOverTime.append(x)
                    yAccelOverTime.append(y)
                    zAccelOverTime.append(z)
                    let xAvg = xAccelOverTime.reduce(0.0,+)/Float(xAccelOverTime.count)
                    let yAvg = yAccelOverTime.reduce(0.0,+)/Float(yAccelOverTime.count)
                    let zAvg = zAccelOverTime.reduce(0.0,+)/Float(zAccelOverTime.count)
                    currentAcceleration = (xAvg, yAvg, zAvg)
                    boseAccelerationData.append((xAvg,yAvg,zAvg))
                    offset += 7
                    print("Accelerometer Data: x - \(x), y - \(y), z - \(z)")
                case 1:
                    let denominator = Float(pow(2.0, 12.0))
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    let accuracy = UInt8(value[offset+6])
//                    boseGyroData.append((x,y,z))
                    offset += 7
                    print("Gyroscope Data: \(sensorID) \(timestamp) \(x) \(y) \(z) \(accuracy)")
                case 2:
                    let denominator = Float(pow(2.0, 14.0))
                    var x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    var y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    var z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    var w = Float(Int16(value[offset+6]) << 8 | Int16(value[offset+7]))/denominator
                    let accuracy = Int16(value[offset+8]) << 8 | Int16(value[offset+9])
                    offset += 10
                    let d = sqrtf(w*w+x*x+y*y+z*z)
                    x /= d
                    y /= d
                    z /= d
                    w /= d
                    let pitch = getPitch(x: x, y: y, z: z, w: w)
                    let roll = getRoll(x: x, y: y, z: z, w: w)
                    let yaw = getYaw(x: x, y: y, z: z, w: w)
                    currentHeading = (pitch, roll, yaw)
                    print("Rotation Data: \(pitch) \(roll) \(yaw) \(accuracy)")
                case 3:
                    let denominator = Float(pow(2.0, 14.0))
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    let w = Float(Int16(value[offset+6]) << 8 | Int16(value[offset+7]))/denominator
                    offset += 8
                    print("Game Rotation Data: \(sensorID) \(timestamp) \(x) \(y) \(z) \(w)")
                case 4:
                    let denominator = Float(pow(2.0, 12.0))
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    let accuracy = UInt8(value[offset+6])
                    print("Orientation: \(x) \(y) \(z) \(accuracy)")
                    offset += 7
                case 5:
                    let denominator = Float(pow(2.0, 12.0))
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    let accuracy = UInt8(value[offset+6])
                    print("Magnetometer: \(x) \(y) \(z) \(accuracy)")
                    offset += 7
                case 6:
                    let denominator = Float(pow(2.0, 12.0))
                    let x = Float(Int16(value[offset]) << 8 | Int16(value[offset+1]))/denominator
                    let y = Float(Int16(value[offset+2]) << 8 | Int16(value[offset+3]))/denominator
                    let z = Float(Int16(value[offset+4]) << 8 | Int16(value[offset+5]))/denominator
                    let xbias = Float(Int16(value[offset+6]) << 8 | Int16(value[offset+7]))/denominator
                    let ybias = Float(Int16(value[offset+8]) << 8 | Int16(value[offset+9]))/denominator
                    let zbias = Float(Int16(value[offset+10]) << 8 | Int16(value[offset+11]))/denominator
                    print("Uncalibrated Magnetometer: \(x) \(y) \(z) \(xbias) \(ybias) \(zbias)")
                    offset += 12
                default:
                    print("Unsupported sensor \(sensorID)")
                }
            }
            return value
        }
        return Data()
    }
    
    func parseGestureInformation(using gestureInformationCharacteristic: CBCharacteristic) -> Data {
        print("---- Gesture Information ----")
        let length = 3
        var offset = 0
        if let value = gestureInformationCharacteristic.value {
            while(offset + length <= value.count) {
                let gestureID = UInt8(value[offset])
                let configurationPayloadLength = UInt16(value[offset+1]) << 8 | UInt16(value[offset+2])
                print("Gesture Information Entry: \(gestureID) \(configurationPayloadLength)")
                offset += length
            }
            return value
        }
        return Data()
    }
    
    func parseGestureConfiguration(using gestureConfigurationCharacteristic: CBCharacteristic) -> Data {
        print("---- Gesture Configuration ----")
        let length = 2
        var offset = 0
        if let value = gestureConfigurationCharacteristic.value {
            while(offset + length <= value.count) {
                let gestureID = UInt8(value[offset])
                let enabled = UInt8(value[offset+1])
                print("Gesture Configuration Entry: \(gestureID) \(enabled)")
                offset += length
            }
            return value
        }
        return Data()
    }
  
  public func fakeHeadShake() {
    detectedGesture = "headShake"
    detectedGestureTime = Date()
    
    if (detectedGesture == "headShake" && (StaticLinker.viewController!.activityTypeLabel.text == "Walking" ||
        StaticLinker.viewController!.activityTypeLabel.text == "Stationary")) {
          print("Volume down now")
          currentVolume = audioSession.outputVolume
          MPVolumeView.setVolume(0.3)
          StaticLinker.viewController!.atCrossing = true
    }
  }
  
  public func resetVolume() {
    print(currentVolume)
    MPVolumeView.setVolume(currentVolume)
  }
  
    
    func parseGestureData(using gestureDataCharacteristic: CBCharacteristic) -> Data {
        print("---- Gesture Data ----")
        var offset = 0
        if let value = gestureDataCharacteristic.value {
            let gestureID = UInt8(value[offset])
            let timestamp = UInt16(value[offset+1]) << 8 | UInt16(value[offset+2])
            detectedGesture = gestures[Int(gestureID)-128]
            
          // check if at crossing
            if (detectedGesture == "headShake" && (StaticLinker.viewController!.activityTypeLabel.text == "Walking" ||
                StaticLinker.viewController!.activityTypeLabel.text == "Stationary")) {
                  print("Volume down now")
                  currentVolume = audioSession.outputVolume
                  MPVolumeView.setVolume(0.3)
                  StaticLinker.viewController!.atCrossing = true
            }
          
            detectedGestureTime = Date()
            print("Gesture Data Entry: \(gestureID), \(detectedGesture), \(timestamp)")
        }
        return Data()
    }
    
    func sign(num: Float) -> Float {
        return (num < 0.0 ? -1.0 : num > 0.0 ? 1.0 : 0.0)
    }
    
    func getPitch(x: Float, y: Float, z: Float, w: Float) -> Float {
        let sinp = 2*(x*w+y*z)
        let cosp = 1-2*(x*x+y*y)
        let pitch = atan2f(sinp, cosp)
        return pitch
    }
    
    func getRoll(x: Float, y: Float, z: Float, w: Float) -> Float {
        let sinr = 2.0*(y*w-x*z)
        if (abs(sinr) >= 1) {
            return -1.0*(sign(num: sinr)*Float.pi/2)
        }
        return -1.0*asinf(sinr)
    }
    
    func getYaw(x: Float, y: Float, z: Float, w: Float) -> Float {
        let siny = 2*(z*w+x*y)
        let cosy = 1-2*(y*y+z*z)
        return -1.0*atan2f(siny, cosy)
    }
}


extension MPVolumeView {
  static func setVolume(_ volume: Float) {
    let volumeView = MPVolumeView()
    let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider

    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
      slider?.value = volume
    }
  }

}
