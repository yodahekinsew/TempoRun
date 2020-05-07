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
import CoreMotion

class NewRunViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
  
//  @IBOutlet weak var launchPromptStackView: UIStackView!
//  @IBOutlet weak var dataStackView: UIStackView!
  
  @IBOutlet weak var readyLabel: UILabel!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var stopButton: UIButton!
  @IBOutlet weak var distanceLabel: UILabel!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var paceLabel: UILabel!
//  @IBOutlet weak var mapContainerView: UIView!
  @IBOutlet weak var mapView: MKMapView!
//  @IBOutlet weak var badgeStackView: UIStackView!
//  @IBOutlet weak var badgeImageView: UIImageView!
//  @IBOutlet weak var badgeInfoLabel: UILabel!
  
  public var atCrossing = false
  
  // Pedometer
  private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
  var cadence = 0;
  @IBOutlet weak var activityTypeLabel: UILabel!
  
  @IBOutlet weak var stepsCountLabel: UILabel!
  @IBOutlet weak var BPMLabel: UILabel!
  
  // Bose Properties
  private var centralManager: CBCentralManager!
  private var peripheral: CBPeripheral!
  private var boseCharacteristics: [CBCharacteristic]?
  private var sensorDataCharacteristic: CBCharacteristic?
  private var sensorInformationCharacteristic: CBCharacteristic?
  private var sensorConfigurationCharacteristic: CBCharacteristic?
  var bosePeripheral = BoseFramesPeripheral()
  private var stepDetector = StepDetector()
  private var positionTracker = PositionTracker()
  public var runningBPM: Float = 0.0
  
  private var run: Run?
  private let locationManager = LocationManager.shared
  private var seconds = 0
  private var timer: Timer?
  private var distance = Measurement(value: 0, unit: UnitLength.meters)
  private var locationList: [CLLocation] = []
//  private var upcomingBadge: Badge!
  private let successSound: AVAudioPlayer = {
    guard let successSound = NSDataAsset(name: "success") else {
      return AVAudioPlayer()
    }
    return try! AVAudioPlayer(data: successSound.data)
  }()
  
  override func viewDidLoad() {
    StaticLinker.viewController = self
    super.viewDidLoad()
//    dataStackView.isHidden = true // required to work around behavior change in Xcode 9 beta 1
//    badgeStackView.isHidden = true // required to work around behavior change in Xcode 9 beta 1
    
    // Do any additional setup after loading the view.
    //stepDetector.testFFT()
    startUpdating()
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
//    launchPromptStackView.isHidden = true
//    dataStackView.isHidden = false
    startButton.isHidden = true
    stopButton.isHidden = false
    readyLabel.isHidden = true
    let pedometer = CMPedometer()
//    mapContainerView.isHidden = false
    mapView.removeOverlays(mapView.overlays)
    
    seconds = 0
    distance = Measurement(value: 0, unit: UnitLength.meters)
    locationList.removeAll()
//    badgeStackView.isHidden = false
//    upcomingBadge = Badge.next(for: 0)
//    badgeImageView.image = UIImage(named: upcomingBadge.imageName)
    updateDisplay()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      self.eachSecond()
    }
    startLocationUpdates()
  }
  
  private func stopRun() {
//    launchPromptStackView.isHidden = false
//    dataStackView.isHidden = true
    startButton.isHidden = false
    stopButton.isHidden = true
    readyLabel.isHidden = false
//    mapContainerView.isHidden = true
//    badgeStackView.isHidden = true
    
    locationManager.stopUpdatingLocation()
  }
  
  func eachSecond() {
    seconds += 1
//    checkNextBadge()
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
    
//    let distanceRemaining = upcomingBadge.distance - distance.value
//    let formattedDistanceRemaining = FormatDisplay.distance(distanceRemaining)
//    badgeInfoLabel.text = "\(formattedDistanceRemaining) until \(upcomingBadge.name)"
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
  
//  private func checkNextBadge() {
//    let nextBadge = Badge.next(for: distance.value)
//    if upcomingBadge != nextBadge {
//      badgeImageView.image = UIImage(named: nextBadge.imageName)
//      upcomingBadge = nextBadge
//      successSound.play()
//      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
//    }
//  }
  
  // -----Bose Code-----
  func enableSensors(using sensorConfigurationCharacteristic: CBCharacteristic?) {
      var dataToWrite = Data(count: 12)
      dataToWrite[0] = 0
      dataToWrite[2] = 20
      dataToWrite[3] = 1
      dataToWrite[5] = 20
      dataToWrite[6] = 2
      dataToWrite[8] = 20
      dataToWrite[9] = 3
      if let characteristic = sensorConfigurationCharacteristic {
          peripheral.writeValue(dataToWrite, for: characteristic, type: .withResponse)
      }
  }
  
  func enableGestures(using gestureConfigurationCharacteristic: CBCharacteristic?) {
    var dataToWrite = Data(count: 6)
    dataToWrite[0] = 129
    dataToWrite[1] = 1
    dataToWrite[2] = 130
    dataToWrite[3] = 1
    dataToWrite[4] = 131
    dataToWrite[5] = 1
    if let characteristic = gestureConfigurationCharacteristic {
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
                  enableSensors(using: characteristic)
              case BoseFramesPeripheral.gestureConfigurationUUID:
                  print("Found Gesture Configuration Characteristic")
                  enableGestures(using: characteristic)
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
      switch(characteristic.uuid) {
      case BoseFramesPeripheral.sensorDataUUID:
          var data = bosePeripheral.parseSensorData(using: characteristic)
          if (bosePeripheral.boseAccelerationData.count == 1000) {
              runningBPM = stepDetector.getBPM(using: bosePeripheral.boseAccelerationData)
          }
      case BoseFramesPeripheral.sensorInformationUUID:
          var data = bosePeripheral.parseSensorInformation(using: characteristic)
      case BoseFramesPeripheral.sensorConfigurationUUID:
          var data = bosePeripheral.parseSensorConfiguration(using: characteristic)
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
                if self?.atCrossing == true {
                  print("volume back up")
                  self?.bosePeripheral.resetVolume()
                  self?.atCrossing = false
                }
              } else if activity.automotive {
                  self?.activityTypeLabel.text = "Automotive"
              }
          }
      }
    }
  

  /*
    Hook up to a button to fake head shake data
    @IBAction func fakeHeadShake(_ sender: Any) {
      bosePeripheral.fakeHeadShake()
    }
 */
 
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
class StaticLinker
{
     static var viewController : NewRunViewController? = nil
}

