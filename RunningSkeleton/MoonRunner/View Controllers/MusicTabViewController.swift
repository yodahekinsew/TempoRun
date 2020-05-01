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

class MusicTabViewController: UIViewController {

  @IBOutlet var trackName: UILabel!
  @IBOutlet var artistName: UILabel!
  @IBOutlet var contextName: UILabel!
  @IBOutlet var albumArtImageView: UIImageView!
  
  private var subscribedToPlayerState: Bool = false
  private var playerState: SPTAppRemotePlayerState?
  private var currentContext = URL(string:"")
  private var BPMTable = Dictionary<String, Double>()

  override func viewDidLoad() {
    super.viewDidLoad()
    if appRemote?.isConnected == true {
      appRemoteConnected()
    }
    getPlayerState()
  }
  
  var defaultCallback: SPTAppRemoteCallback {
      get {
          return {[weak self] _, error in
              if let error = error {
                 print(error as NSError)
              }
          }
      }
  }

  var appRemote: SPTAppRemote? {
      get {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.appRemote
      }
  }
  
  // update view with now playing
  private func updateNowPlaying(_ playerState: SPTAppRemotePlayerState) {
    trackName.text = playerState.track.name
    artistName.text = playerState.track.artist.name
    contextName.text = playerState.contextTitle
    if (playerState.contextURI != currentContext) {
      print("new context")
      self.BPMTable = Dictionary<String, Double>()
      makeBPMTable(context: playerState.contextURI)
      currentContext = playerState.contextURI
    }
    fetchAlbumArtForTrack(playerState.track) { (image) -> Void in
        self.updateAlbumArtWithImage(image)
    }
  }
  
  // get what is currently playing
  private func getPlayerState() {
      appRemote?.playerAPI?.getPlayerState { (result, error) -> Void in
          guard error == nil else { return }
          let playerState = result as! SPTAppRemotePlayerState
          self.updateNowPlaying(playerState)
      }
  }
  
  // set up subscriber for what is playing
  private func subscribeToPlayerState() {
      guard (!subscribedToPlayerState) else { return }
      appRemote?.playerAPI!.delegate = self
      appRemote?.playerAPI?.subscribe { (_, error) -> Void in
          guard error == nil else { return }
          self.subscribedToPlayerState = true
      }
  }
  
  //Play Pause Button
  @IBAction func Button(_ sender: UIButton) {
    if sender.currentTitle == "play" {
      appRemote?.playerAPI?.resume(defaultCallback)
      sender.setTitle("pause", for: UIControl.State.normal)
    }
    else if sender.currentTitle == "pause"{
      //pause music here!
      appRemote?.playerAPI?.pause(defaultCallback)
      sender.setTitle("play", for: UIControl.State.normal)
    }
  }
  
  // initial connection
  func appRemoteConnected() {
    subscribeToPlayerState()
    getPlayerState()
  }
  // next song
  @IBAction func NextSong(_ sender: Any) {
    appRemote?.playerAPI?.skip(toNext: defaultCallback)
    print("Next Song Pressed!");
  }
  
  // previous song
  @IBAction func PreviousSong(_ sender: Any) {
    appRemote?.playerAPI?.skip(toPrevious: defaultCallback)
    print("Previous Song Pressed!");
  }
  
  // TODO: to implement
  @IBAction func SetBPM(_ sender: Any) {
    let testBPM = 100.0
    let threshold = 5.0
    print("Set BPM Pressed!");
    //print(BPMTable)
    // queue songs with matching BPM
    for (song, tempo) in BPMTable {
      if abs(tempo - testBPM) < threshold {
        print("queuing this song: ", song, "with BPM of ", tempo)
        appRemote?.playerAPI?.enqueueTrackUri(song, callback: defaultCallback)
      }
    }
    
    appRemote?.playerAPI?.skip(toNext: defaultCallback)
  
  }
  
  // slowly transition to new artwork
  private func updateAlbumArtWithImage(_ image: UIImage) {
      self.albumArtImageView.image = image
      let transition = CATransition()
      transition.duration = 0.3
      transition.type = CATransitionType.fade
      self.albumArtImageView.layer.add(transition, forKey: "transition")
  }
  
  // get album art for new track
  private func fetchAlbumArtForTrack(_ track: SPTAppRemoteTrack, callback: @escaping (UIImage) -> Void ) {
      appRemote?.imageAPI?.fetchImage(forItem: track, with:CGSize(width: 300, height: 300), callback: { (image, error) -> Void in
          guard error == nil else { return }

          let image = image as! UIImage
          callback(image)
      })
  }
  
  private func makeBPMTable(context : URL) {
 
    appRemote?.contentAPI?.fetchContentItem(forURI: context.absoluteString, callback: {  (result, error) -> Void in
      if let _ = result {
        self.appRemote?.contentAPI?.fetchChildren(of: result as! SPTAppRemoteContentItem, callback: { (children, error) -> Void in
          var songs = children as! [SPTAppRemoteContentItem]
          for song in songs {
            self.getBPMFromTrack(uri: song.uri)
          }
          
          })
      }
    })
  }
  
  private func getBPMFromTrack( uri : String) {
    let parts = uri.components(separatedBy: ":")
    var id = ""
    if parts.count > 2 {
      id = parts[2]
    }
    let endpoint = "https://api.spotify.com/v1/audio-features/" + id
    var tempo = 0.0
    guard let requestUrl = URL(string: endpoint) else { print("cannot create URL")
          fatalError() }
    var urlRequest = URLRequest(url: requestUrl)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("Bearer " + (appRemote?.connectionParameters.accessToken)!, forHTTPHeaderField: "Authorization")

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
                self.BPMTable[uri] = tempo

              }
          }
        }
    }
      
    task.resume()
    }
}
 
extension MusicTabViewController: SPTAppRemotePlayerStateDelegate {
       func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
           self.playerState = playerState
           updateNowPlaying(playerState)
       }
}
