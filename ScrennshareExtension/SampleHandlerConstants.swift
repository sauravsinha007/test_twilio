//
//  SampleHandlerConstants.swift
//  TestScreenSharing
//
//  Created by Saurav Sinha on 22/12/21.
//

import Foundation

struct SampleHandlerConstants {
    
    static let kBroadcastExtensionBundleId = "KureNetwork.KureApp.ScreenshareExtension" //SampleHandlerConstants.getTargetName() == "Kure"  ?  "KureNetwork.KureApp.ScreenshareExtension" :  "KureNetwork.KureStag.ScreenshareExtension"
    static let K_SCREEN = "screen"
    static let K_BUNDLE_IDENTIFIER = "group.com.kurenetwork.kure"
    static let USER_PHONE_NO = "userPhoneNumber"
    static let ROOM_NAME = "roomName"
    static let SCREEN_SHARE_IDENTIFIER = "Screenshare"
//    static let TOKEN_URL = "https://api-data.kureapp.com/twilio-new/call.php?identity="
//    static let STOP_SCREENSHARE_ERROR_MESSAGE = "You have stopped screen sharing"
//    static let K_REGION = "gll"
    
    static func saveContentInUserDefault(_ content: String?, key : String?) {
        if let lKey = key, !lKey.isEmpty,
           let lContent = content, !lContent.isEmpty {
            if let lUserDefaults=UserDefaults(suiteName:SampleHandlerConstants.K_BUNDLE_IDENTIFIER) {
                lUserDefaults.set(lContent, forKey: lKey)
                lUserDefaults.synchronize()
            }
        }
    }
    
    static func getContentFromUserDefault(_ key : String?) -> Any? {
        if let lKey = key, !lKey.isEmpty {
            if let lUserDefaults=UserDefaults(suiteName:SampleHandlerConstants.K_BUNDLE_IDENTIFIER),
               let lContent = lUserDefaults.value(forKey: lKey)
            {
                return lContent
            }
        }
        return nil
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
    
    static func getTargetName() -> String {
        let lTargetName = Bundle.main.infoDictionary?["TARGET_NAME"] as? String ?? ""
        return lTargetName
    }
/*
    static func getTwilioAccessTokenForScreenShare(_ pCompletionHandler:@escaping(AccessTokenApiCallCompletionHandler))
    {
        guard let lPhoneNo = SampleHandlerConstants.getContentFromUserDefault(SampleHandlerConstants.USER_PHONE_NO) as? String,
              !lPhoneNo.isEmpty else {
            pCompletionHandler(nil,"Not having User Phone Number")
            return
        }
        let lIdentifier : String = lPhoneNo + SampleHandlerConstants.SCREEN_SHARE_IDENTIFIER
        let lUrlString = SampleHandlerConstants.TOKEN_URL + lIdentifier
        
        guard let lUrl = URL(string: lUrlString) else {
            pCompletionHandler(nil,"Access Token User is not correct")
            return
        }

        let task = URLSession.shared.dataTask(with: lUrl) {(data, response, error) in
            guard let data = data,
                  let lResponse = SampleHandlerConstants.jsonFromResponse(objectData: data),
                  let lToken = lResponse["token"] as? String else {
                pCompletionHandler(nil,error?.localizedDescription)
                    return
            }
            //String(data: data, encoding: .utf8)
            print("ScreenShare-Debug accessToken = \(lToken)")
            pCompletionHandler(lToken,error?.localizedDescription)
        }
        
        task.resume()
    }
    */
    static func isScreenshareParticipant(_ participantId : String?) -> Bool {
        if let lId = participantId, !lId.isEmpty,
           lId.contains(SampleHandlerConstants.SCREEN_SHARE_IDENTIFIER) {
            return true
        }
        return false
    }
    
    static func isScreenshareParticipantOwner(_ participantId : String?, loginUserId : String?) -> Bool {
        if let lId = participantId, !lId.isEmpty,
           lId.contains(SampleHandlerConstants.SCREEN_SHARE_IDENTIFIER),
           let lUserId = loginUserId, !lUserId.isEmpty,
           lId.contains(lUserId) {
            return true
        }
        return false
    }
    
    static func isParticipantOwner(_ participantId : String?) -> Bool {
        var lIsOwner = false
        if let lPhoneNo = SampleHandlerConstants.getContentFromUserDefault(SampleHandlerConstants.USER_PHONE_NO) as? String,
              !lPhoneNo.isEmpty,
            let lId = participantId, !lId.isEmpty,
            lPhoneNo == lId {
            lIsOwner = true
        }
        return lIsOwner
    }
}
