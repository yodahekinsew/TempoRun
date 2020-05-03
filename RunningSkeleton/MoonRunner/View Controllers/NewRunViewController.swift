/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreLocation
import MapKit
import AVFoundation
import CoreBluetooth


class NewRunViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
  
  @IBOutlet weak var launchPromptStackView: UIStackView!
  @IBOutlet weak var dataStackView: UIStackView!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var stopButton: UIButton!
  @IBOutlet weak var distanceLabel: UILabel!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var paceLabel: UILabel!
  @IBOutlet weak var mapContainerView: UIView!
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var badgeStackView: UIStackView!
  @IBOutlet weak var badgeImageView: UIImageView!
  @IBOutlet weak var badgeInfoLabel: UILabel!
  
  // Bose Properties
  private var centralManager: CBCentralManager!
  private var peripheral: CBPeripheral!
  private var boseCharacteristics: [CBCharacteristic]?
  private var sensorDataCharacteristic: CBCharacteristic?
  private var sensorInformationCharacteristic: CBCharacteristic?
  private var sensorConfigurationCharacteristic: CBCharacteristic?
  private var bosePeripheral = BoseFramesPeripheral()
  private var stepDetector = StepDetector()
  private var positionTracker = PositionTracker()
  
  private var run: Run?
  private let locationManager = LocationManager.shared
  private var seconds = 0
  private var timer: Timer?
  private var distance = Measurement(value: 0, unit: UnitLength.meters)
  private var locationList: [CLLocation] = []
  private var upcomingBadge: Badge!
  private let successSound: AVAudioPlayer = {
    guard let successSound = NSDataAsset(name: "success") else {
      return AVAudioPlayer()
    }
    return try! AVAudioPlayer(data: successSound.data)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    dataStackView.isHidden = true // required to work around behavior change in Xcode 9 beta 1
    badgeStackView.isHidden = true // required to work around behavior change in Xcode 9 beta 1
    
    // Do any additional setup after loading the view.
    //stepDetector.testFFT()
    positionTracker.setupLocationManager()
    positionTracker.startRecordingLocation()
    centralManager = CBCentralManager(delegate: self, queue: nil)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
    locationManager.stopUpdatingLocation()
  }
  
  @IBAction func startTapped() {
    startRun()
  }
  
  @IBAction func stopTapped() {
    let alertController = UIAlertController(title: "End run?",
                                            message: "Do you wish to end your run?",
                                            preferredStyle: .actionSheet)
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alertController.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      self.stopRun()
      self.saveRun()
      self.performSegue(withIdentifier: .details, sender: nil)
    })
    alertController.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
      self.stopRun()
      _ = self.navigationController?.popToRootViewController(animated: true)
    })
    
    present(alertController, animated: true)
  }
  
  private func startRun() {
    launchPromptStackView.isHidden = true
    dataStackView.isHidden = false
    startButton.isHidden = true
    stopButton.isHidden = false
    mapContainerView.isHidden = false
    mapView.removeOverlays(mapView.overlays)
    
    seconds = 0
    distance = Measurement(value: 0, unit: UnitLength.meters)
    locationList.removeAll()
    badgeStackView.isHidden = false
    upcomingBadge = Badge.next(for: 0)
    badgeImageView.image = UIImage(named: upcomingBadge.imageName)
    updateDisplay()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      self.eachSecond()
    }
    startLocationUpdates()
  }
  
  private func stopRun() {
    launchPromptStackView.isHidden = false
    dataStackView.isHidden = true
    startButton.isHidden = false
    stopButton.isHidden = true
    mapContainerView.isHidden = true
    badgeStackView.isHidden = true
    
    locationManager.stopUpdatingLocation()
  }
  
  func eachSecond() {
    seconds += 1
    checkNextBadge()
    updateDisplay()
  }
  
  private func updateDisplay() {
    let formattedDistance = FormatDisplay.distance(distance)
    let formattedTime = FormatDisplay.time(seconds)
    let formattedPace = FormatDisplay.pace(distance: distance,
                                           seconds: seconds,
                                           outputUnit: UnitSpeed.minutesPerMile)
    
    distanceLabel.text = "Distance:  \(formattedDistance)"
    timeLabel.text = "Time:  \(formattedTime)"
    paceLabel.text = "Pace:  \(formattedPace)"
    
    let distanceRemaining = upcomingBadge.distance - distance.value
    let formattedDistanceRemaining = FormatDisplay.distance(distanceRemaining)
    badgeInfoLabel.text = "\(formattedDistanceRemaining) until \(upcomingBadge.name)"
  }
  
  private func startLocationUpdates() {
    locationManager.delegate = self
    locationManager.activityType = .fitness
    locationManager.distanceFilter = 10
    locationManager.startUpdatingLocation()
  }
  
  private func saveRun() {
    let newRun = Run(context: CoreDataStack.context)
    newRun.distance = distance.value
    newRun.duration = Int16(seconds)
    newRun.timestamp = Date()
    
    for location in locationList {
      let locationObject = Location(context: CoreDataStack.context)
      locationObject.timestamp = location.timestamp
      locationObject.latitude = location.coordinate.latitude
      locationObject.longitude = location.coordinate.longitude
      newRun.addToLocations(locationObject)
    }
    
    CoreDataStack.saveContext()
    
    run = newRun
  }
  
  private func checkNextBadge() {
    let nextBadge = Badge.next(for: distance.value)
    if upcomingBadge != nextBadge {
      badgeImageView.image = UIImage(named: nextBadge.imageName)
      upcomingBadge = nextBadge
      successSound.play()
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
  }
  
  // -----Bose Code-----
  func turnOnSensors(using sensorConfigurationCharacteristic: CBCharacteristic?) {
      var dataToWrite = Data(count: 12)
      dataToWrite[0] = 0
      dataToWrite[2] = 20
      dataToWrite[3] = 1
      dataToWrite[6] = 2
      dataToWrite[8] = 2
      dataToWrite[9] = 3
      if let characteristic = sensorConfigurationCharacteristic {
          peripheral.writeValue(dataToWrite, for: characteristic, type: .withResponse)
      }
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
                  peripheral.discoverCharacteristics([BoseFramesPeripheral.sensorConfigurationUUID, BoseFramesPeripheral.sensorInformationUUID, BoseFramesPeripheral.sensorDataUUID, BoseFramesPeripheral.gestureConfigurationUUID, BoseFramesPeripheral.gestureInformationUUID, BoseFramesPeripheral.gestureDataUUID], for: service)
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
                  print("Found Sensor Configuration Characteristic")
              case BoseFramesPeripheral.sensorInformationUUID:
                  sensorInformationCharacteristic = characteristic
                  print("Found Sensor Information Characteristic")
              case BoseFramesPeripheral.sensorDataUUID:
                  sensorDataCharacteristic = characteristic
                  print("Found Sensor Data Characteristic")
                  peripheral.setNotifyValue(true, for: characteristic)
                  turnOnSensors(using: characteristic)
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

}

// MARK: - Navigation

extension NewRunViewController: SegueHandlerType {
  enum SegueIdentifier: String {
    case details = "RunDetailsViewController"
    case music = "MusicTabViewController"
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segueIdentifier(for: segue) {
    case .details:
      let destination = segue.destination as! RunDetailsViewController
      destination.run = run
    case .music:
      let destination = segue.destination as! MusicTabViewController
      
    }
    
  }
}

// MARK: - Location Manager Delegate

extension NewRunViewController: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for newLocation in locations {
      let howRecent = newLocation.timestamp.timeIntervalSinceNow
      guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue }
      
      if let lastLocation = locationList.last {
        let delta = newLocation.distance(from: lastLocation)
        distance = distance + Measurement(value: delta, unit: UnitLength.meters)
        let coordinates = [lastLocation.coordinate, newLocation.coordinate]
        mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
        let region = MKCoordinateRegion.init(center: newLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
      }
      
      locationList.append(newLocation)
    }
  }
}

// MARK: - Map View Delegate

extension NewRunViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = .blue
    renderer.lineWidth = 3
    return renderer
  }
}
