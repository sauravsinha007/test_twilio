//
//  ViewController+CallKit.swift
//  TestScreenSharing
//
//  Created by Saurav Sinha on 21/12/21.
//

import Foundation

import TwilioVideo
import CallKit
import AVFoundation

// MARK: ------------------------ CXProviderDelegate ------------------------
extension ViewController : CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        logMessage(messageText: "providerDidReset:")

        // AudioDevice is enabled by default
        self.audioDevice.isEnabled = false
        
        mRoom?.disconnect()
    }

    func providerDidBegin(_ provider: CXProvider) {
        logMessage(messageText: "providerDidBegin")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        logMessage(messageText: "provider:didActivateAudioSession:")

        self.audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        logMessage(messageText: "provider:didDeactivateAudioSession:")
        
        audioDevice.isEnabled = false
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        logMessage(messageText: "provider:timedOutPerformingAction:")
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        logMessage(messageText: "provider:performStartCallAction:")

        callKitProvider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        
        performRoomConnect(uuid: action.callUUID, roomName: action.handle.value) { (success) in
            if (success) {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logMessage(messageText: "provider:performAnswerCallAction:")

        performRoomConnect(uuid: action.callUUID, roomName: K_ROOM_NAME) { (success) in
            if (success) {
                action.fulfill(withDateConnected: Date())
            } else {
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")

        mRoom?.disconnect()

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("provier:performSetMutedCallAction:")
        
    //    muteAudio(isMuted: action.isMuted)
        
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provier:performSetHeldCallAction:")

        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls

        guard let call = calls.first(where:{$0.uuid == action.callUUID}) else {
            action.fail()
            return
        }

//        if call.isOnHold {
//            holdCall(onHold: false)
//        } else {
//            holdCall(onHold: true)
//        }
        action.fulfill()
    }
}

// MARK:- Call Kit Actions
extension ViewController {

    func performStartCallAction(uuid: UUID, roomName: String?) {
        let callHandle = CXHandle(type: .generic, value: roomName ?? "")
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        
        startCallAction.isVideo = true
        
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction)  { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }
            NSLog("StartCallAction transaction request successful")
        }
    }

    func reportIncomingCall(uuid: UUID, roomName: String?, completion: ((NSError?) -> Void)? = nil) {
        let callHandle = CXHandle(type: .generic, value: roomName ?? "")

        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = false
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = true

        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if error == nil {
                NSLog("Incoming call successfully reported.")
            } else {
                NSLog("Failed to report incoming call successfully: \(String(describing: error?.localizedDescription)).")
            }
            completion?(error as NSError?)
        }
    }

    func performEndCallAction(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                return
            }

            NSLog("EndCallAction transaction request successful")
        }
    }

    func performRoomConnect(uuid: UUID, roomName: String? , completionHandler: @escaping (Bool) -> Swift.Void) {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            do {
                var lTokenURL = self.tokenUrl + K_ROOM_NAME
                if isParticipantBtnClick == true {
                    lTokenURL = self.tokenUrl + (self.mParticiantName ?? "")
                    isParticipantBtnClick = false
                }
                accessToken = try TokenUtils.fetchToken(url: lTokenURL)
            } catch {
                let message = "Failed to fetch access token"
                logMessage(messageText: message)
                return
            }
        }

        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()

        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = ConnectOptions(token: accessToken) { (builder) in

            // Use the local media that we prepared earlier.
            builder.audioTracks = self.mLocalAudioTrack != nil ? [self.mLocalAudioTrack!] : [LocalAudioTrack]()
            builder.videoTracks = self.mLocalVideoTrack != nil ? [self.mLocalVideoTrack!] : [LocalVideoTrack]()

            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec]
            }
            
            // Use the preferred video codec
            if let preferredVideoCodec = Settings.shared.videoCodec {
                builder.preferredVideoCodecs = [preferredVideoCodec]
            }
            
            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }

            // Use the preferred signaling region
            if let signalingRegion = Settings.shared.signalingRegion {
                builder.region = signalingRegion
            }

            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = roomName

            // The CallKit UUID to assoicate with this Room.
            builder.uuid = uuid
        }
        
        // Connect to the Room using the options we provided.
        mRoom = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        
        logMessage(messageText: "Attempting to connect to room \(String(describing: roomName))")
        
        //self.showRoomUI(inRoom: true)
        
        self.callKitCompletionHandler = completionHandler
    }
}