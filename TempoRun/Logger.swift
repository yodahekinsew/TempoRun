//
//  Logger.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/25/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import MessageUI

class Logger: UIViewController, CLLocationManagerDelegate, MFMailComposeViewControllerDelegate {
    
    var locationManager:CLLocationManager? = nil
    var isRecording = false
    var logFile:FileHandle? = nil
    var alert:UIAlertController? = nil
    let DATA_FILE_NAME = "log.csv"
    
    @IBAction func emailLogFile(_ sender: UIButton) {
        if !MFMailComposeViewController.canSendMail() {
            self.alert = UIAlertController(title: "Can't send mail", message: "Please set up an email account on this phone to send mail", preferredStyle: UIAlertController.Style.alert)
            let ok = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: {(action:UIAlertAction) in
                self.dismiss(animated: true, completion: nil)
            })
            self.alert?.addAction(ok)
            self.present(self.alert!, animated: true, completion: nil)
            return
        }

        let fileData = NSData(contentsOfFile: self.getPathToLogFile())
        if fileData == nil || fileData?.length == 0 {
            return
        }
        let emailTitle = "Position File"
        let messageBody = "Data from PositionLogger"
        let mc = MFMailComposeViewController()
        mc.mailComposeDelegate = self
        mc.setSubject(emailTitle)
        mc.setMessageBody(messageBody, isHTML: false)
        mc.addAttachmentData(fileData as! Data, mimeType: "text/plain", fileName: DATA_FILE_NAME)
        self.present(mc, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        switch result {
        case MFMailComposeResult.cancelled:
            NSLog("Mail cancelled")
        case MFMailComposeResult.saved:
            NSLog("Mail saved")
        case MFMailComposeResult.sent:
            NSLog("Mail sent")
        case MFMailComposeResult.failed:
            NSLog("Mail sent failure: " + (error?.localizedDescription)!)
        }

        self.dismiss(animated: true, completion: nil)
    }
    
    func getPathToLogFile() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let filePath = documentsPath + "/" + DATA_FILE_NAME
        return filePath
    }

    func openFileForWriting() -> FileHandle? {
        let fileManager = FileManager.default
        let created = fileManager.createFile(atPath: self.getPathToLogFile(), contents: nil, attributes: nil)
        if !created {
            assert(false, "Failed to create file at " + self.getPathToLogFile() + ".")
        }
        return FileHandle(forWritingAtPath: self.getPathToLogFile())
    }

    func logLineToDataFile(_ line: String) {
        self.logFile?.write(line.data(using: String.Encoding.utf8)!)
        print(line)
    }

    func resetLogFile() {
        self.logFile?.closeFile()
        self.logFile = self.openFileForWriting()
        if self.logFile == nil {
            assert(false, "Couldn't open file for writing (" + self.getPathToLogFile() + ").")
        }
    }
}
