    //
//  ViewController.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/15/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import UIKit
import CoreBluetooth
    

class ViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var boseCharacteristics: [CBCharacteristic]?
    


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // If we're powered on, start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central state update")
        if central.state != .poweredOn {
            print("Central is not powered on")
        } else {
            print("Central scanning for", BoseFramesPeripheral.boseServiceUUID);
            centralManager.scanForPeripherals(withServices: [BoseFramesPeripheral.boseServiceUUID],
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    // Handles the result of the scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // We've found it so stop scan
        self.centralManager.stopScan()

        // Copy the peripheral instance
        self.peripheral = peripheral
        self.peripheral.delegate = self

        // Connect!
        self.centralManager.connect(self.peripheral, options: nil)

    }
    
    // The handler if we do connect succesfully
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            print(peripheral.name)
            print("Connected to your Bose Frames")
            peripheral.discoverServices([BoseFramesPeripheral.boseServiceUUID])
       }
    }
    
    // Handles discovery event
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discoverd something")
        if let services = peripheral.services {
            for service in services {
                print(service.uuid)
                if service.uuid == BoseFramesPeripheral.boseServiceUUID {
                    print("Bose AR service found")
                    //Now kick off discovery of characteristics
                    peripheral.discoverCharacteristics([BoseFramesPeripheral.sensorConfigurationUUID, BoseFramesPeripheral.sensorInformationUUID, BoseFramesPeripheral.sensorDataUUID], for: service)
                    return
                }
            }
        }
    }
    
    // Handling discovery of characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Discovered a characteristic")
        if let characteristics = service.characteristics {
            boseCharacteristics = characteristics
            for characteristic in characteristics {
                print(characteristic.uuid)
                peripheral.readValue(for: characteristic)
                switch (characteristic.uuid) {
                case BoseFramesPeripheral.sensorConfigurationUUID:
                    print("Found Sensor Configuration Characteristic")
                case BoseFramesPeripheral.sensorInformationUUID:
                    print("Found Sensor Information Characteristic")
                case BoseFramesPeripheral.sensorDataUUID:
                    print("Found Sensor Data Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                case BoseFramesPeripheral.gestureConfigurationUUID:
                    print("Found Gesture Configuration Characteristic")
                case BoseFramesPeripheral.gestureInformationUUID:
                    print("Found Gesture Information Characteristic")
                case BoseFramesPeripheral.gestureDataUUID:
                    print("Found Gesture Data Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    print("Found Unsupported Characteristic")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        printCharacteristic(using: characteristic)
        switch(characteristic.uuid) {
        case BoseFramesPeripheral.sensorDataUUID:
            var data = BoseFramesPeripheral().parseSensorData(using: characteristic)
        case BoseFramesPeripheral.sensorInformationUUID:
            var data = BoseFramesPeripheral().parseSensorInformation(using: characteristic)
        case BoseFramesPeripheral.sensorConfigurationUUID:
            var data = BoseFramesPeripheral().parseSensorConfiguration(using: characteristic)
            data[2] = 20 //Turn on Accelerometer Data with a Sampling Rate of 20ms
//            data[5] = 20 //Turn on Gyroscope Data
//            data[8] = 20 //Turn on Rotation Data
//            data[11] = 20 //Turn on Game Rotation Data
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        case BoseFramesPeripheral.gestureDataUUID:
            var data = BoseFramesPeripheral().parseGestureData(using: characteristic)
        case BoseFramesPeripheral.gestureInformationUUID:
            var data = BoseFramesPeripheral().parseGestureInformation(using: characteristic)
        case BoseFramesPeripheral.gestureConfigurationUUID:
            var data = BoseFramesPeripheral().parseGestureConfiguration(using: characteristic)
        default:
            print("Cannot Parse Unsupported Characteristic")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Successfully wrote a value for \(characteristic.uuid)")
    }
    
    func printCharacteristic(using characteristic: CBCharacteristic) {
        print("Characteristic UUID: \(characteristic.uuid)")
        print("Characteristic isNotifying: \(characteristic.isNotifying)")
        print("Characteristic properties: \(characteristic.properties)")
        print("Characteristic descriptors: \(characteristic.descriptors)")
        if let value = characteristic.value {
            print("Characteristic value: \(value) \(value.count)")
        }
    }
    
    
}

