//
//  ViewController.swift
//  TestScreenSharing
//
//  Created by Saurav Sinha on 21/12/21.
//

import UIKit
import CallKit
import AVFoundation
import TwilioVideo
import ReplayKit

class ViewController: UIViewController {

    // MARK: ----------------------- IBOutlets  -----------------------
    @IBOutlet weak var mCollectionView: UICollectionView?
    @IBOutlet weak var previewView: VideoView?
    @IBOutlet weak var micButton: UIButton?
    @IBOutlet weak var participantVideoView: UIView?
    @IBOutlet weak var screenshareBtn: UIButton?
    // MARK: ----------------------- Properties  -----------------------
    var accessToken = "TWILIO_ACCESS_TOKEN"
    // Configure remote URL to fetch token from
    var tokenUrl = K_TOKEN_BASE_URL
    public var mRoom: Room?
    public var mCamera: CameraSource?
    public var mLocalVideoTrack: LocalVideoTrack?
    public var mLocalAudioTrack: LocalAudioTrack?
    
    var remoteParticipant: RemoteParticipant?
    var remoteView: VideoView?
    
    var audioDevice: DefaultAudioDevice = DefaultAudioDevice()
    
    // CallKit components
    var callKitProvider: CXProvider
    var callKitCallController: CXCallController
    var callKitCompletionHandler: ((Bool)->Swift.Void?)? = nil
    var isParticipantBtnClick : Bool = false
    var mParticipantArray  = [RemoteParticipant]()
    var mParticiantName : String?
    
    // MARK: ----------------------- IBActions  -----------------------
    @IBAction func screenSahringBtnAction(_ sender: AnyObject) {
        self.view.endEditing(true)
    }
    
    @objc func connectBtnAction() {
        performStartCallAction(uuid: UUID(), roomName: K_ROOM_NAME)
    }
    
    @objc func participantBtnAction() {
        self.showAlertViewWithTextFld()
        
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        if let room = mRoom, let uuid = room.uuid {
            logMessage(messageText: "Attempting to disconnect from room \(room.name)")
            performEndCallAction(uuid: uuid)
        }
    }
    
    @IBAction func muteButtonAction(sender: UIButton) {
        if sender.isSelected == true {
            self.micButton?.isSelected = false
        } else {
            self.micButton?.isSelected = true
        }
        
        self.muteAudio(isMuted: self.micButton?.isSelected ?? false)
    }
    
    // MARK: ----------------------- Lifecycle  -----------------------
    
    required init?(coder aDecoder: NSCoder) {
        print("\(#function) -- aDecoder")
        let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = true
        configuration.supportedHandleTypes = [.generic]
        if let callKitIcon = UIImage(named: "iconMask80") {
            configuration.iconTemplateImageData = callKitIcon.pngData()
        }

        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()
        super.init(coder: aDecoder)
        //setUpCallKitDelegate()
        callKitProvider.setDelegate(self, queue: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        configureUI()
    }

    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
        
        // We are done with camera
        if let camera = self.mCamera {
            camera.stopCapture()
            self.mCamera = nil
        }
    }
    // MARK: ----------------------- Helpers  ----------------------
    
   private func configureUI() {
       configureNavigationBar()
       registerCellIdentifiers()
       configureScreenSharingUI()
       configureCollectionView()
      // setUpLocalVideoView()
    }
    

    private func configureNavigationBar() {
        self.title = "Video View"
        
        //        self.navigationController?.navigationBar.tintColor = .white
        //        self.navigationController?.navigationBar.backgroundColor = .black
        var lColor : UIColor = .white
        if self.traitCollection.userInterfaceStyle == .dark {
            // User Interface is Dark
            lColor = .white
        } else {
            // User Interface is Light
            lColor = .black
        }
        
        let rightBtn: UIButton = UIButton()
        rightBtn.setTitle("Connect", for: .normal)
        rightBtn.setTitleColor(lColor, for: .normal)
        //btnLeftMenu.setImage(UIImage(named: "backArrow"), for: UIControl.State.normal)
        rightBtn.addTarget(self, action: #selector(connectBtnAction), for: UIControl.Event.touchUpInside)
        rightBtn.frame =  CGRect(x:0, y:0, width: 70, height:44)
        rightBtn.contentHorizontalAlignment = .left
        let barButton = UIBarButtonItem(customView: rightBtn)
        self.navigationItem.rightBarButtonItem = barButton
        
        
        let leftBtn: UIButton = UIButton()
        leftBtn.setTitle("Participant", for: .normal)
        leftBtn.setTitleColor(lColor, for: .normal)
        //btnLeftMenu.setImage(UIImage(named: "backArrow"), for: UIControl.State.normal)
        leftBtn.addTarget(self, action: #selector(participantBtnAction), for: UIControl.Event.touchUpInside)
        leftBtn.frame =  CGRect(x:0, y:0, width: 70, height:44)
        leftBtn.contentHorizontalAlignment = .left
        let barButton2 = UIBarButtonItem(customView: leftBtn)
        self.navigationItem.leftBarButtonItem = barButton2
    }
    
    private func registerCellIdentifiers() {
        // mCollectionView.register(UINib.init(nibName: k_LearnersCellIdentifier, bundle: nil), forCellWithReuseIdentifier: k_LearnersCellIdentifier)
    }
    
    private func setUpLocalVideoView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startPreview()
        }
    }
    
    private func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        let frontCamera = CameraSource.captureDevice(position: .front)
        let backCamera = CameraSource.captureDevice(position: .back)

        if (frontCamera != nil || backCamera != nil) {

            let options = CameraSourceOptions { (builder) in
                if #available(iOS 13.0, *) {
                    // Track UIWindowScene events for the key window's scene.
                    // The example app disables multi-window support in the .plist (see UIApplicationSceneManifestKey).
                    builder.orientationTracker = UserInterfaceTracker(scene: UIApplication.shared.keyWindow!.windowScene!)
                }
            }
            // Preview our local camera track in the local video preview view.
            mCamera = CameraSource(options: options, delegate: self)
            mLocalVideoTrack = LocalVideoTrack(source: mCamera!, enabled: true, name: "Camera")

            // Add renderer to video track for local preview
            if let lPreviewView = self.previewView {
                mLocalVideoTrack?.addRenderer(lPreviewView)
            }
            logMessage(messageText: "Video track created")

//            if (frontCamera != nil && backCamera != nil) {
//                // We will flip camera on tap.
//                let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.flipCamera))
//                self.previewView.addGestureRecognizer(tap)
//            }

            mCamera!.startCapture(device: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    self.logMessage(messageText: "Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView?.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            self.logMessage(messageText:"No front or back capture device found!")
        }
    }
    
    func prepareLocalMedia() {
        // We will share local audio and video when we connect to the Room.
        // Create an audio track.
        if (mLocalAudioTrack == nil) {
            mLocalAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Microphone")

            if (mLocalAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }

        // Create a video track which captures from the camera.
        if (mLocalVideoTrack == nil) {
            self.startPreview()
        }
   }
    
    func logMessage(messageText: String) {
        print("\(#function) = \(messageText)")
        //NSLog(messageText)
       // messageLabel.text = messageText
    }
    
    func muteAudio(isMuted: Bool) {
        if let localAudioTrack = self.mLocalAudioTrack {
            localAudioTrack.isEnabled = !isMuted

            // Update the button title
//            if (!isMuted) {
//                self.micButton?.setTitle("Mute", for: .normal)
//            } else {
//                self.micButton?.setTitle("Unmute", for: .normal)
//            }
        }
    }
}

// MARK: ------------------------  Remote Participant Connect -----------------------

extension ViewController {
    /*
    func setupRemoteVideoView() {
        // Creating `VideoView` programmatically
        if self.remoteView != nil {
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
        }
        let lRect = CGRect(x: 0.0, y: 0.0, width: self.participantVideoView?.frame.size.width ?? 320, height: (self.participantVideoView?.frame.size.height ?? 320))
        self.remoteView = VideoView(frame: lRect, delegate: self)
        
        self.participantVideoView?.insertSubview(self.remoteView!, at: 0)
        
        // `VideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `VideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;
        self.participantVideoView?.backgroundColor = .red
        
//        let centerX = NSLayoutConstraint(item: self.remoteView!,
//                                         attribute: NSLayoutConstraint.Attribute.centerX,
//                                         relatedBy: NSLayoutConstraint.Relation.equal,
//                                         toItem: self.view,
//                                         attribute: NSLayoutConstraint.Attribute.centerX,
//                                         multiplier: 1,
//                                         constant: 0);
//        self.participantVideoView?.addConstraint(centerX)
//        let centerY = NSLayoutConstraint(item: self.remoteView!,
//                                         attribute: NSLayoutConstraint.Attribute.centerY,
//                                         relatedBy: NSLayoutConstraint.Relation.equal,
//                                         toItem: self.view,
//                                         attribute: NSLayoutConstraint.Attribute.centerY,
//                                         multiplier: 1,
//                                         constant: 0);
//        self.participantVideoView?.addConstraint(centerY)
//        let width = NSLayoutConstraint(item: self.remoteView!,
//                                       attribute: NSLayoutConstraint.Attribute.width,
//                                       relatedBy: NSLayoutConstraint.Relation.equal,
//                                       toItem: self.view,
//                                       attribute: NSLayoutConstraint.Attribute.width,
//                                       multiplier: 1,
//                                       constant: 0);
//        self.participantVideoView?.addConstraint(width)
//        let height = NSLayoutConstraint(item: self.remoteView!,
//                                        attribute: NSLayoutConstraint.Attribute.height,
//                                        relatedBy: NSLayoutConstraint.Relation.equal,
//                                        toItem: self.view,
//                                        attribute: NSLayoutConstraint.Attribute.height,
//                                        multiplier: 1,
//                                        constant: 0);
//        self.participantVideoView?.addConstraint(height)
         
    }
    */
     
    /*
    func renderRemoteParticipant(participant : RemoteParticipant) -> Bool {
        // This example renders the first subscribed RemoteVideoTrack from the RemoteParticipant.
        if (self.remoteParticipant != nil) {
            self.remoteParticipant = nil
        }
        
        let videoPublications = participant.remoteVideoTracks
        for publication in videoPublications {
            if let subscribedVideoTrack = publication.remoteTrack,
                publication.isTrackSubscribed {
                print("\(#function) subscribedVideoTrack.name = \(subscribedVideoTrack.name)")
                setupRemoteVideoView()
                subscribedVideoTrack.addRenderer(self.remoteView!)
                self.remoteParticipant = participant
                return true
            }
        }
        return false
    }
    
     */
    /*
    func renderRemoteParticipants(participants : Array<RemoteParticipant>) {
        for participant in participants {
            // Find the first renderable track.
            if participant.remoteVideoTracks.count > 0,
                renderRemoteParticipant(participant: participant) {
                break
            }
        }
    }
     */
    func cleanupRemoteParticipant() {
        if self.remoteParticipant != nil {
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
            self.remoteParticipant = nil
        }
    }
    
    func showRoomUI(inRoom: Bool) {
//        self.connectButton.isHidden = inRoom
//        self.simulateIncomingButton.isHidden = inRoom
//        self.roomTextField.isHidden = inRoom
//        self.roomLine.isHidden = inRoom
//        self.roomLabel.isHidden = inRoom
//        self.micButton.isHidden = !inRoom
//        self.disconnectButton.isHidden = !inRoom
//        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
//        UIApplication.shared.isIdleTimerDisabled = inRoom
//
//        // Show / hide the automatic home indicator on modern iPhones.
//        self.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private func addRemoteParticipantInArray(_ pRemoteParticipant : RemoteParticipant?)
    {
        print(" \(#function) pRemoteParticipant.identity = \(String(describing: pRemoteParticipant?.identity))")
        if(self.isDuplicateRemoteParticipant(pRemoteParticipant) == false) {
            pRemoteParticipant?.delegate = self
            self.mParticipantArray.append(pRemoteParticipant!)
        }
    }
    
    private func isDuplicateRemoteParticipant(_ participant : RemoteParticipant?) -> Bool {
        var lIsDuplicate = false
        if let lParticipant = participant,
           let _ = mParticipantArray.filter({$0.identity == lParticipant.identity}).first {
                lIsDuplicate = true
        }
        return lIsDuplicate
    }
    
    func removeRemoteParticipantFromArray(_ pRemoteParticipant : RemoteParticipant?)
    {
        if let lRemoteParticipant = pRemoteParticipant {
            if let index = mParticipantArray.firstIndex(of:lRemoteParticipant) {
                mParticipantArray.remove(at: index)
            }
        }
    }
    
    func getIndexOfParaticipantFromArray(_ pParticipant : RemoteParticipant?) -> Int? {
        var lIndex  = 0
        if let lRemoteParticipant = pParticipant {
            for lParticipant in self.mParticipantArray
            {
                print(" \(#function) lParticipant.identity = \(lParticipant.identity)")
                if(lParticipant.identity == lRemoteParticipant.identity) {
                    break
                }
                lIndex = lIndex + 1
            }
        }
        return lIndex
    }
    
    private func isParticipantHasVideoTrack(_ participant : RemoteParticipant?) -> Bool {
        var lHasVideoTrack = false
        if VideoConstants.getVideoTrackOfRemoteParticipant(participant) != nil {
            lHasVideoTrack = true
        }
        return lHasVideoTrack
    }
}

// MARK: ------------------------  CameraSourceDelegate -----------------------
extension ViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        logMessage(messageText: "Camera source failed with error: \(error.localizedDescription)")
    }
}

// MARK: ------------------------  VideoViewDelegate ------------------------
extension ViewController : VideoViewDelegate {
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: ------------------------ RoomDelegate ------------------------
extension ViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        // At the moment, this example only supports rendering one Participant at a time.
        
        logMessage(messageText: "Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")

        // This example only renders 1 RemoteVideoTrack at a time. Listen for all events to decide which track to render.
        for remoteParticipant in room.remoteParticipants {
            print("remoteParticipant = \(remoteParticipant.identity)")
            //remoteParticipant.delegate = self
            self.addRemoteParticipantInArray(remoteParticipant)
        }
        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls

        // Let the call provider know that the outgoing call has connected
        if let uuid = room.uuid, let call = calls.first(where:{$0.uuid == uuid}) {
            if call.isOutgoing {
                callKitProvider.reportOutgoingCall(with: uuid, connectedAt: nil)
            }
        }
        
        self.callKitCompletionHandler!(true)
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")

        if  let uuid = room.uuid, let error = error as? TwilioVideoSDK.Error {
            var reason = CXCallEndedReason.remoteEnded

            if error.code != .roomRoomCompletedError {
                reason = .failed
            }

            self.callKitProvider.reportCall(with: uuid, endedAt: nil, reason: reason)
        }

        self.cleanupRemoteParticipant()
        self.mRoom = nil
        self.showRoomUI(inRoom: false)
        self.callKitCompletionHandler = nil
      //  self.userInitiatedDisconnect = false
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        logMessage(messageText: "Failed to connect to room with error: \(error.localizedDescription)")

        self.callKitCompletionHandler!(false)
        self.mRoom = nil
        self.showRoomUI(inRoom: false)
    }

    func roomIsReconnecting(room: Room, error: Error) {
        logMessage(messageText: "Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        logMessage(messageText: "Reconnected to room \(room.name)")
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        // Listen for events from all Participants to decide which RemoteVideoTrack to render.
        participant.delegate = self

        logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
        self.addRemoteParticipantInArray(participant)
        self.reloadCollectionView()
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
        self.removeRemoteParticipantFromArray(participant)
        // Nothing to do in this example. Subscription events are used to add/remove renderers.
    }
}

// MARK: ------------------------ RemoteParticipantDelegate ------------------------
extension ViewController : RemoteParticipantDelegate {

    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.

        logMessage(messageText: "didSubscribeToVideoTrack to \(publication.trackName) video track for Participant \(participant.identity)")
        
        if self.isDuplicateRemoteParticipant(participant) == true,
           let lIndex = self.getIndexOfParaticipantFromArray(participant) {
            print("VideoManager :\(#function) line : \(#line) \(participant.identity) update participant")
            mParticipantArray[lIndex] = participant
        } else {
            self.addRemoteParticipantInArray(participant)
        }
        self.reloadCollectionView()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
            self.reloadParticipantCell(participant)
        }
        
       // if (self.remoteParticipant == nil) {
      //      _ = renderRemoteParticipant(participant: participant)
       // }
                    
    }
    
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")
        if self.isParticipantHasVideoTrack(participant) == false {
            self.removeRemoteParticipantFromArray(participant)
        }
        self.reloadCollectionView()
        self.removeZoomView()
//        if self.remoteParticipant == participant {
//            cleanupRemoteParticipant()
//
//            // Find another Participant video to render, if possible.
//            if var remainingParticipants = mRoom?.remoteParticipants,
//                let index = remainingParticipants.firstIndex(of: participant) {
//                remainingParticipants.remove(at: index)
//              //  renderRemoteParticipants(participants: remainingParticipants)
//            }
//        }
         
    }

    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
       
        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}


// MARK:- ---------------- Screensharing related function ----------------
extension ViewController {
    private func configureScreenSharingUI() {
        // Swap the button for an RPSystemBroadcastPickerView.
        #if !targetEnvironment(simulator)
        // iOS 13.0 throws an NSInvalidArgumentException when RPSystemBroadcastPickerView is used to start a broadcast.
        // https://stackoverflow.com/questions/57163212/get-nsinvalidargumentexception-when-trying-to-present-rpsystembroadcastpickervie
   
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0,
                                                                   y: 0,
                                                                   width: 60,
                                                                   height: 60))
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.preferredExtension = SampleHandlerConstants.kBroadcastExtensionBundleId
        pickerView.showsMicrophoneButton = false
        
        // Theme the picker view to match the white that we want.
        if let lBtn = pickerView.subviews.first as? UIButton {
            //            lBtn.imageView?.tintColor = UIColor.red
            //            lBtn.imageView?.image = UIImage(named: "blank_img")
//            lBtn.setImage(UIImage(named: "blank_img"), for: .normal)
//            lBtn.setImage(UIImage(named: "blank_img"), for: .selected)
           // lBtn.addTarget(self, action: #selector(screensharePickerAction), for: .touchUpInside)
        }
        
        print("RPSystemBroadcastPickerView added")
        view.addSubview(pickerView)
       // self.broadcastPickerView = pickerView
        //broadcastButton.isEnabled = false
        //broadcastButton.titleEdgeInsets = UIEdgeInsets(top: 34, left: 0, bottom: 0, right: 0)
        
        let centerX = NSLayoutConstraint(item:pickerView,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: screenshareBtn,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: pickerView,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: screenshareBtn,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         multiplier: 1,
                                         constant: -10);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: pickerView,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: self.screenshareBtn,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: pickerView,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: self.screenshareBtn,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
        #endif
    }
    
    
    @objc func screensharePickerAction() {
//        SampleHandlerConstants.saveContentInUserDefault(KAppDelegate.uso.userPhone, key: SampleHandlerConstants.USER_PHONE_NO)
//        SampleHandlerConstants.saveContentInUserDefault(VideoManager.sharedManager.mRoomAddress, key: SampleHandlerConstants.ROOM_NAME)
        
    }
    
    private func configureCollectionView() {
        mCollectionView?.register(UINib(nibName: "VideoCell", bundle:nil), forCellWithReuseIdentifier: "VideoCell")
        if let layout = mCollectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            let lWidth : CGFloat  = ((self.participantVideoView?.frame.size.width ?? 320) - 20)/2
            let lHeight : CGFloat  = ((self.participantVideoView?.frame.size.width ?? 320) - 20)/2
            layout.sectionInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            let lSize = CGSize(width:lWidth, height: lHeight)
            print("Video Cell Size = ", lSize)
            layout.itemSize = lSize
        }
    }
    
    @objc private func reloadCollectionView() {
        DispatchQueue.main.async {
            self.mCollectionView?.reloadData()
        }
    }

    @objc private func reloadParticipantCell(_ pParticipant : RemoteParticipant?) {
        DispatchQueue.main.async { [weak self] in
            guard let lParticipant = pParticipant,
                  let lIndex = self?.getIndexOfParaticipantFromArray(lParticipant),
                  let lCell = self?.mCollectionView?.cellForItem(at: IndexPath(item: lIndex, section: 0)) as? VideoCell else {
                return
            }
            let lIndexPath = IndexPath(item: lIndex, section: 0)
            if let lVisibleIndexPaths = self?.visibleCollectionViewCellIndexPath(),
               lVisibleIndexPaths.contains(lIndexPath) {
                lCell.renderVideoTrackHavingPaticipant(lParticipant)
            }
        }
    }
    
    private func visibleCollectionViewCellIndexPath() -> [IndexPath]? {
        let lVisibleIndexPathList = self.mCollectionView?.indexPathsForVisibleItems
        return lVisibleIndexPathList
    }
    
    func showVideoViewInZoomInState(_ pParticipant : RemoteParticipant?)
    {
        if let lRemoteParticipant = pParticipant,
           let lVideoContainer = self.participantVideoView
        {
            DispatchQueue.main.async {
                self.removeZoomView()
                
                let lZoomVideoView : VideoView = VideoView(frame: CGRect.zero, delegate: self)
                lZoomVideoView.delegate = self
                lZoomVideoView.tag = 11111
                //lZoomVideoView.contentMode = .scaleAspectFill
                VideoConstants.setContentOfVideoView(lZoomVideoView, participant: lRemoteParticipant, isZoomMode: true)
                lVideoContainer.addSubview(lZoomVideoView)
                
                lZoomVideoView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    lZoomVideoView.leadingAnchor.constraint(equalTo: lVideoContainer.leadingAnchor, constant: 0),
                    lZoomVideoView.trailingAnchor.constraint(equalTo: lVideoContainer.trailingAnchor, constant: 0),
                    lZoomVideoView.topAnchor.constraint(equalTo: lVideoContainer.topAnchor, constant: 0),
                    lZoomVideoView.bottomAnchor.constraint(equalTo: lVideoContainer.bottomAnchor, constant: 0)
                ])
                if let lVideoTrack  = VideoConstants.getVideoTrackOfRemoteParticipant(lRemoteParticipant) {
                    lVideoTrack.addRenderer(lZoomVideoView)
                    VideoConstants.setLayoutForVideoView(lZoomVideoView, videoTrack: lVideoTrack, isZooomMode: true)
                }
                
                let lTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGestureInZoomInVideoView(_:)))
                lZoomVideoView.addGestureRecognizer(lTapGesture)
                
                self.previewView?.isHidden = true
                //lVideoContainer.bringSubviewToFront(self.previewView!)
              

            }
        }
    }
    
    @objc private func handleTapGestureInZoomInVideoView(_ recognizer: UITapGestureRecognizer?)
    {
        print("\(#function)")
        self.removeZoomView()
    }
    
    private func removeZoomView() {
        guard let lSubViews = self.participantVideoView?.subviews else {
            return
        }
        for view in lSubViews {
            if view.tag == 11111 {
                view.removeFromSuperview()
                break
            }
        }
        
        self.previewView?.isHidden = false
    }
    
    @objc private func tapAction(sender:UITapGestureRecognizer){
        if let lIndex = sender.view?.tag {
            let lParticipant = self.mParticipantArray[lIndex]
            self.showVideoViewInZoomInState(lParticipant)
        }
    }
    
    private func showAlertViewWithTextFld()
    {
        let alertController = UIAlertController(title: "Enter Participant Name", message: "", preferredStyle: .alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Enter Participant Name"
            textField.keyboardType = .default
            textField.text = "participant-1"
        }
        let lJoinAction = UIAlertAction(title: "Join", style: .default, handler: { alert -> Void in
            if let firstTextField = alertController.textFields?.first,
               let lText = firstTextField.text, !lText.isEmpty  {
                self.mParticiantName = lText
                self.isParticipantBtnClick = true
                self.performStartCallAction(uuid: UUID(), roomName: K_ROOM_NAME)
            }
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { (action : UIAlertAction!) -> Void in })
        
        alertController.addAction(lJoinAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
}


// MARK: - UICollectionViewDelegate Datasouces and Delegates

extension ViewController : UICollectionViewDataSource, UICollectionViewDelegate
{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let lRowCount = self.mParticipantArray.count
        print("Row Count = \(lRowCount)")
        return lRowCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // get a reference to our storyboard cell
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
       // let lVideoView : VideoView = VideoManager.sharedManager.mVideoViewArray[indexPath.row]
        let lParticipant : RemoteParticipant = self.mParticipantArray[indexPath.item]
        cell.setUpViewCellViewHavingInfo(lParticipant)
        // reuse edits
            cell.renderVideoTrackHavingPaticipant(lParticipant)
                
        cell.layoutIfNeeded()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapAction(sender:)))
        cell.fullScrImageView.addGestureRecognizer(tapGesture)
        tapGesture.view?.tag = indexPath.item
        return cell
    }
   
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
    /*
    //------ UICollectionViewDelegateFlowLayout ----------------
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let lSize : CGSize = CGSize(width: (self.mCollectionView!.frame.size.width / 2), height: (self.mCollectionView!.frame.size.height / 2))
        return lSize
        //return CGSize(width: 220 , height: 155)
    }
    //b/w 2 cell vertically
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    //b/w 2 cell horizontally
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    //one whole section
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
    }
     */
}
