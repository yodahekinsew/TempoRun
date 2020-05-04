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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SPTAppRemoteDelegate {

  var window: UIWindow?
  
  // Spotify parameters
  let SpotifyClientID = "24031a58b9d44ab193ea364e4ecd6b80"
  let SpotifyRedirectURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!
  var accessToken = ""

  lazy var configuration = SPTConfiguration(
    clientID: SpotifyClientID,
    redirectURL: SpotifyRedirectURL
  )

  lazy var appRemote: SPTAppRemote = {
    let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .error)
    appRemote.connectionParameters.accessToken = self.accessToken
    appRemote.delegate = self
    return appRemote
  }()
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().barTintColor = .black
    let locationManager = LocationManager.shared
    locationManager.requestWhenInUseAuthorization()
    
    return true
  }
  
  // Start Spotify authorization callback
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    let parameters = appRemote.authorizationParameters(from: url);

          if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = access_token
              self.accessToken = access_token
          } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
              print(error_description)
          }
    return true
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    if self.appRemote.isConnected {
      self.appRemote.disconnect()
    }
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    if self.appRemote.connectionParameters.accessToken != "" {
      self.appRemote.connect()
    } else if self.appRemote.isConnected == false {
      self.appRemote.authorizeAndPlayURI("")
    }
    
  }
  
  func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
    print("connected")
  }

  
  func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
    print("disconnected")
  }
  func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
    print("failed")
  }


  
  func applicationDidEnterBackground(_ application: UIApplication) {
    CoreDataStack.saveContext()
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
    CoreDataStack.saveContext()
  }
  
}

