//
//  Utils.swift
//  TestScreenSharing
//
//  Created by Saurav Sinha on 21/12/21.
//

import Foundation
import TwilioVideo

// Helper to determine if we're running on simulator or device
struct PlatformUtils {
    static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
            isSim = true
        #endif
        return isSim
    }()
}

struct TokenUtils {
    static func fetchToken(url : String) throws -> String {
        print("\(#function) = \(url)")
        var token: String = "TWILIO_ACCESS_TOKEN"
        let requestURL: URL = URL(string: url)!
        do {
            let data = try Data(contentsOf: requestURL)
            if let lResponse = TokenUtils.jsonFromResponse(objectData: data),
                 let lToken = lResponse["token"] as? String  {
                token = lToken
            }
            print("token = \(token)")
//            if let tokenReponse = String(data: data, encoding: String.Encoding.utf8) {
//                token = tokenReponse
//            }
        } catch let error as NSError {
            print ("Invalid token url, error = \(error)")
            throw error
        }
        return token
    }
    
    static func jsonFromResponse(objectData: Data?) -> [String : Any]? {
        var json: [String : Any]?
        if objectData != nil {
            do {
                if let objectData = objectData {
                    json = try JSONSerialization.jsonObject(
                        with: objectData,
                        options: .mutableContainers) as? [String : Any]
                }
            } catch {
                 return nil
            }
            return json
        }
        return nil
    }
}

struct VideoConstants {
    
    static public func isScreenshareVideoTrack(_ pVideoTrak : VideoTrack?) -> Bool {
        if let lVideoTrack = pVideoTrak,
           lVideoTrack.name == SampleHandlerConstants.K_SCREEN {
            return true
        }
        return false
    }
    
    static func getVideoTrackOfRemoteParticipant(_ participant : RemoteParticipant?) -> VideoTrack? {
        var lVidoeTrack : VideoTrack?
        if let lParticipant = participant {
            let lVideoTrackList = lParticipant.remoteVideoTracks
            for lTrack in lVideoTrackList where lTrack.remoteTrack != nil {
                lVidoeTrack = lTrack.remoteTrack
            }
        }
        
        return lVidoeTrack
    }
    
    static func setLayoutForVideoView(_ pVideoView : VideoView?, videoTrack : VideoTrack? = nil, isZooomMode : Bool = false) {
        guard let lVideoView = pVideoView else {
            return
        }
        
        var lBgColor : UIColor = .clear
        var lIsScreenShareVideoTrack = false
        if VideoConstants.isScreenshareVideoTrack(videoTrack) == true {
            lIsScreenShareVideoTrack = true
        }
        let lBorderColor = lIsScreenShareVideoTrack == true ? UIColor.red : UIColor.clear
        
        if isZooomMode == true
           || lIsScreenShareVideoTrack == true {
            lBgColor = .blue
        }
        lVideoView.setLayout(WithBorderWidth: 2.0, borderColor: lBorderColor, radius: 0, andBackgroundColor: lBgColor)
    }
    
    static func setContentOfVideoView(_ pVideoView : VideoView?, participant : RemoteParticipant?, isZoomMode : Bool? = false) {
        guard let lVideoView = pVideoView else {
            return
        }
        var lContentMode : UIView.ContentMode = .scaleAspectFill
//        var lIsScreenShareVideoTrack = false
//        if let lVideoTrack = VideoManager.getVideoTrackOfRemoteParticipant(lParticipant),
//           VideoManager.isScreenshareVideoTrack(lVideoTrack) == true {
//            lIsScreenShareVideoTrack = true
//        }
        if isZoomMode == true {
            lContentMode = .scaleAspectFit
        }
        lVideoView.contentMode = lContentMode
    }
}




extension UIView {
    
    @objc func setLayout(WithBorderWidth borderWidth:CGFloat, borderColor:UIColor?, radius aRadius:CGFloat, andBackgroundColor bgColor:UIColor?)
     {
         self.layer.borderWidth = borderWidth
         self.layer.cornerRadius = aRadius
         if(borderColor != nil) {
             self.layer.borderColor = borderColor?.cgColor
         }
         
         if(bgColor != nil) {
             self.layer.backgroundColor = bgColor?.cgColor
         }
     }
}
