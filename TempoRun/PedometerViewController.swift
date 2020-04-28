
//
//  PedometerViewController.swift
//  TempoRun
//
//  Created by Joshua Verdejo on 4/27/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import UIKit
import CoreMotion

class PedometerViewController: UIViewController {
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    
    @IBOutlet weak var activityTypeLabel: UILabel!
    @IBOutlet weak var stepsCountLabel: UILabel!
    @IBOutlet weak var BPMLabel: UILabel!
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
            let cadence = pedometerData.currentCadence?.intValue ?? 0
            self?.BPMLabel.text = String(cadence*60);
                
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
    override func viewDidLoad() {
        startUpdating()
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
