//
//  SceneDelegate.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/15/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate,
SPTAppRemoteDelegate {

    static private let kAccessTokenKey = "access-token-key"
    private let redirectUri = URL(string:"spotify-ios-quick-start://spotify-login-callback")!
    private let clientIdentifier = "24031a58b9d44ab193ea364e4ecd6b80"
    //Josh:24031a58b9d44ab193ea364e4ecd6b80
    //Serena: 78ec9630ae5743b4af7f9536a52bdbf1
    var window: UIWindow?
    
    // make app remote that conencts to spotify
    lazy var appRemote: SPTAppRemote = {
        let configuration = SPTConfiguration(clientID: self.clientIdentifier, redirectURL: self.redirectUri)
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()

    var accessToken = UserDefaults.standard.string(forKey: kAccessTokenKey) {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(accessToken, forKey: SceneDelegate.kAccessTokenKey)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        let parameters = appRemote.authorizationParameters(from: url);
        if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = access_token
            self.accessToken = access_token
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print(errorDescription)
        }
    }
    
    // if scene is active, start connection process
    func sceneDidBecomeActive(_ scene: UIScene) {
        if let _ = self.appRemote.connectionParameters.accessToken {
            connect()
        }
        if appRemote.isConnected != true {
            appRemote.authorizeAndPlayURI("")
            connect()
        }
    }
    
    // if scene becomes inactive, disconnect the app remote
    func sceneWillResignActive(_ scene: UIScene) {
        playerViewController.appRemoteDisconnect()
        appRemote.disconnect()
    }
    
    // authorizes after connection is established
    func connect() {
        self.appRemote.connect()
        playerViewController.appRemoteConnecting()
    }

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        self.appRemote = appRemote
        print("connected succesfully to spotify")
        playerViewController.setAccessToken(token: self.accessToken!)
        playerViewController.appRemoteConnected()
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("didFailConnectionAttemptWithError")
        playerViewController.appRemoteDisconnect()
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("didDisconnectWithError")
        playerViewController.appRemoteDisconnect()
    }
    
    var playerViewController: ViewController {
        get {
            return self.window?.rootViewController as! ViewController
        }
    }
}

