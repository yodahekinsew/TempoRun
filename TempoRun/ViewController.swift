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
                if characteristic.uuid == BoseFramesPeripheral.sensorConfigurationUUID {
                    peripheral.readValue(for: characteristic)
                    print("Sensor Configuration characteristic found")
                } else if characteristic.uuid == BoseFramesPeripheral.sensorInformationUUID {                    peripheral.readValue(for: characteristic)
                    print("Sensor Information characteristic found")
                } else if characteristic.uuid == BoseFramesPeripheral.sensorDataUUID {                    peripheral.readValue(for: characteristic)
                    print("Setting sensor data as notifier")
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Sensor Data characteristic found");
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        printCharacteristic(using: characteristic)
        if characteristic.uuid == BoseFramesPeripheral.sensorDataUUID {
            BoseFramesPeripheral().parseSensorData(using: characteristic)
        }
        if characteristic.uuid == BoseFramesPeripheral.sensorConfigurationUUID {
            var newData = BoseFramesPeripheral().parseSensorConfiguration(using: characteristic)
            newData[2] = 20
            print("writing value")
            peripheral.writeValue(newData, for: characteristic, type: .withResponse)
        }
        if characteristic.uuid == BoseFramesPeripheral.sensorInformationUUID {
            BoseFramesPeripheral().parseSensorInformation(using: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
//        guard let data = characteristic.value else { return }
//        print("\nValue: \(data.toHexEncodedString()) \nwas written to Characteristic:\n\(characteristic)")
//        if(error != nil){
//            print("\nError while writing on Characteristic:\n\(characteristic). Error Message:")
//            print(error as Any)
//        }
        print("Successfully wrote a value")
    }
    
    func printCharacteristic(using characteristic: CBCharacteristic) {
        print("Characteristic UUID: \(characteristic.uuid)")
        print("Characteristic isNotifying: \(characteristic.isNotifying)")
        print("Characteristic properties: \(characteristic.properties)")
        print("Characteristic descriptors: \(characteristic.descriptors)")
        if let value = characteristic.value {
            print("Characteristic value: \(value)")
            print(value.count)
        }
    }
    
    
}

