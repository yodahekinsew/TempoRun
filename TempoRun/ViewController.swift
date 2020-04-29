//
//  ViewController.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/15/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion
    
class ViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
    // Pedometer
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var cadence = 0;
    
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var boseCharacteristics: [CBCharacteristic]?
    private var sensorDataCharacteristic: CBCharacteristic?
    private var sensorInformationCharacteristic: CBCharacteristic?
    private var sensorConfigurationCharacteristic: CBCharacteristic?
    private var bosePeripheral = BoseFramesPeripheral()
    private var stepDetector = StepDetector()
    
    // Spotify
    private let playURI = ""
    private var subscribedToPlayerState: Bool = false
    private var playerState: SPTAppRemotePlayerState?
    private var accessToken = ""
    private var currentBPM = 0.0
    @IBOutlet weak var songName: UILabel!
    @IBOutlet weak var songArtists: UILabel!
    @IBOutlet weak var songBPM: UILabel!
    
    // Pedometer
    @IBOutlet weak var activityTypeLabel: UILabel!
    @IBOutlet weak var stepsCountLabel: UILabel!
    @IBOutlet weak var BPMLabel: UILabel!
    @IBOutlet weak var accelerometerToggle: UIButton!
    private var accelerometerEnabled = false
    @IBAction func toggleAccelerometer(_ sender: Any) {
        var dataToWrite = Data(count: 12)
        if accelerometerEnabled {
            accelerometerEnabled = false
            accelerometerToggle.setTitle("Enable Accelerometer", for: .normal)
            dataToWrite[2] = 0
        } else {
            accelerometerEnabled = true
            accelerometerToggle.setTitle("Disable Accelerometer", for: .normal)
            dataToWrite[2] = 20
        }
        dataToWrite[3] = 1
        dataToWrite[6] = 2
        dataToWrite[9] = 3
        if let characteristic = sensorConfigurationCharacteristic {
            peripheral.writeValue(dataToWrite, for: characteristic, type: .withResponse)
        }
    }
    
    @IBAction func SetBPM(_ sender: Any) {
        let seconds = 30.0
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Put your code which should be executed with a delay here
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        startUpdating()
        // Do any additional setup after loading the view.
//        stepDetector.testFFT()
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
                    sensorConfigurationCharacteristic = characteristic
                    accelerometerToggle.isHidden = false
                    print("Found Sensor Configuration Characteristic")
                case BoseFramesPeripheral.sensorInformationUUID:
                    sensorInformationCharacteristic = characteristic
                    print("Found Sensor Information Characteristic")
                case BoseFramesPeripheral.sensorDataUUID:
                    sensorDataCharacteristic = characteristic
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
            var data = bosePeripheral.parseSensorData(using: characteristic)
            if (bosePeripheral.boseAccelerationData.count == 1000)
            {
                let bpm = stepDetector.getBPM(using: bosePeripheral.boseAccelerationData)
                print(bpm)
            }
        case BoseFramesPeripheral.sensorInformationUUID:
            var data = bosePeripheral.parseSensorInformation(using: characteristic)
        case BoseFramesPeripheral.sensorConfigurationUUID:
            var data = bosePeripheral.parseSensorConfiguration(using: characteristic)
//            data[2] = 20 //Turn on Accelerometer Data with a Sampling Rate of 20ms
//            data[5] = 20 //Turn on Gyroscope Data
//            data[8] = 20 //Turn on Rotation Data
//            data[11] = 20 //Turn on Game Rotation Data
//            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        case BoseFramesPeripheral.gestureDataUUID:
            var data = bosePeripheral.parseGestureData(using: characteristic)
        case BoseFramesPeripheral.gestureInformationUUID:
            var data = bosePeripheral.parseGestureInformation(using: characteristic)
        case BoseFramesPeripheral.gestureConfigurationUUID:
            var data = bosePeripheral.parseGestureConfiguration(using: characteristic)
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
    

    // Spotify song viewing code
    var defaultCallback: SPTAppRemoteCallback {
        get {
            return {[weak self] _, error in
                if let error = error {
                    print(error)
                }
            }
        }
    }

    var appRemote: SPTAppRemote? {
        get {
            return (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.appRemote
        }
    }

    // subscribes to changes in player state
    private func subscribeToPlayerState() {
        guard (!subscribedToPlayerState) else { return }
        appRemote?.playerAPI!.delegate = self
        appRemote?.playerAPI?.subscribe { (_, error) -> Void in
            guard error == nil else { return }
            self.subscribedToPlayerState = true
        }
    }


    // APP REMOTE
    func appRemoteConnecting() {
        print("trying to connect to spotify")

    }

    func appRemoteConnected() {
        subscribeToPlayerState()
        appRemote?.playerAPI?.getPlayerState { (result, error) -> Void in
            guard error == nil else { return }
            let playerState = result as! SPTAppRemotePlayerState
            self.updateNowPlaying(playerState: playerState)
        }
    }

    func appRemoteDisconnect() {
        self.subscribedToPlayerState = false
    }

    // updates track name and artist
    func updateNowPlaying( playerState: SPTAppRemotePlayerState) {
        self.songName.text = playerState.track.name
        self.songArtists.text = playerState.track.artist.name
        let parts = playerState.track.uri.components(separatedBy: ":")
        if parts.count > 2 {
            getBPMFromTrack(id: parts[2])
        }
    }

    func updateBPMDisplay() {
        self.songBPM.text = currentBPM.description
    }

    func setAccessToken(token: String) {
        self.accessToken = token
    }

    // updates the BPM of the track on a player state change
    func getBPMFromTrack( id: String) {
        let endpoint = "https://api.spotify.com/v1/audio-features/" + id
        guard let requestUrl = URL(string: endpoint) else { print("cannot create URL")
            fatalError() }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer " + self.accessToken, forHTTPHeaderField: "Authorization")

          let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                  if let error = error {
                      print("Error took place \(error)")
                      return
                  }

                  // Read HTTP Response Status code
                  if let response = response as? HTTPURLResponse {
                      print("Response HTTP Status code: \(response.statusCode)")
                  }

                  // Convert HTTP Response Data to a simple String
                  if let data = data, let dataString = String(data: data, encoding: .utf8) {
                      //print("Response data string:\n \(dataString)")
                    let json_response = try? JSONSerialization.jsonObject(with: data, options: [])
                    if let dictionary = json_response as? [String: Any] {
                        if let tempo = dictionary["tempo"] as? Double{
                            self.currentBPM = tempo

                            DispatchQueue.main.async {
                                self.updateBPMDisplay()
                            }
                        }
                    }
                  }

              }
          task.resume()
      }
    //Pedometer code starts
    private func startTrackingActivityType() {
      activityManager.startActivityUpdates(to: OperationQueue.main) {
          [weak self] (activity: CMMotionActivity?) in

          guard let activity = activity else { return }
          DispatchQueue.main.async {
              if activity.walking {
                  self?.activityTypeLabel.text = "Walking"
              } else if activity.stationary {
                  self?.activityTypeLabel.text = "Stationary"
              } else if activity.running {
                  self?.activityTypeLabel.text = "Running"
              } else if activity.automotive {
                  self?.activityTypeLabel.text = "Automotive"
              }
          }
      }
    }

    private func startCountingSteps() {
      pedometer.startUpdates(from: Date()) {
          [weak self] pedometerData, error in
          guard let pedometerData = pedometerData, error == nil else { return }

          DispatchQueue.main.async {
            self?.stepsCountLabel.text = pedometerData.numberOfSteps.stringValue
            self?.cadence = pedometerData.currentCadence?.intValue ?? 0
            self?.BPMLabel.text = String(self!.cadence*60);

          }

      }
    }


    private func startUpdating() {
      if CMMotionActivityManager.isActivityAvailable() {
          startTrackingActivityType()
      }

      if CMPedometer.isStepCountingAvailable() {
          startCountingSteps()
      }
    }

    
}
    
extension ViewController: SPTAppRemotePlayerStateDelegate {
       func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
           self.playerState = playerState
        updateNowPlaying(playerState: self.playerState as! SPTAppRemotePlayerState)
       }
}



