//
//  VideoCell.swift
//  Kure
//
//  Created by Saurav Sinha on 06/08/20.
//  Copyright © 2020 Kare Partners. All rights reserved.
//

import UIKit
import TwilioVideo

class VideoCell: UICollectionViewCell {
    @IBOutlet weak var mTvVideoView: VideoView!
    @IBOutlet weak var mTitleLbl: UILabel!
    @IBOutlet weak var fullScrImageView: UIImageView!
    
    
    var previousVideoTrack : VideoTrack?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
//        self.mTvVideoView.layer.cornerRadius = 20.0
       // mTvVideoView.contentMode = videoContentMode
    }
    
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mTvVideoView.backgroundColor = .clear
        fullScrImageView.isHidden = true
        mTvVideoView.invalidateRenderer()
    }

     func setUpViewCellViewHavingInfo(_ pInfo : Any?)  {
        print("Start \(#function)")
        let lParticiant : RemoteParticipant? = pInfo as? RemoteParticipant
        let lVideoTrack : VideoTrack? = VideoConstants.getVideoTrackOfRemoteParticipant(lParticiant)
            //(isEmpty(lParticiant.remoteVideoTracks) == false && lParticiant.remoteVideoTracks.count > 0) ? lParticiant.remoteVideoTracks[0].remoteTrack : nil
        print("lVideoTrack in cell = \(lVideoTrack) -- lParticiant.identifier = \(lParticiant?.identity) --- mTvVideoView.hasVideoData = \(mTvVideoView.hasVideoData)")
        VideoConstants.setContentOfVideoView(mTvVideoView, participant: lParticiant)
        //self.renderVideoTrack(lVideoTrack)
       // mTitleLbl.text = lParticiant.identity
         VideoConstants.setLayoutForVideoView(self.mTvVideoView, videoTrack: lVideoTrack)
        self.backgroundColor = .black
        self.mTvVideoView.backgroundColor = .clear
        print("End \(#function)")
    }
    
    private func renderVideoTrack(_ pVideoTrak : VideoTrack?)
    {
       if let _ = pVideoTrak {
        self.fullScrImageView.isHidden = false
            pVideoTrak!.addRenderer(mTvVideoView)
        }
    }
    
    func renderVideoTrackHavingPaticipant(_ pParticipant : RemoteParticipant?)
    {
        let lVideoTrack : VideoTrack? = VideoConstants.getVideoTrackOfRemoteParticipant(pParticipant)
            //(isEmpty(pParticipant?.remoteVideoTracks) == false && pParticipant?.remoteVideoTracks.count ?? 0 > 0) ? pParticipant?.remoteVideoTracks[0].remoteTrack : nil
        VideoConstants.setContentOfVideoView(mTvVideoView, participant: pParticipant)
        if lVideoTrack != nil {
            if previousVideoTrack != nil {
                previousVideoTrack?.removeRenderer(mTvVideoView)
                mTvVideoView.invalidateRenderer()
            }
            self.fullScrImageView.isHidden = false
            lVideoTrack!.addRenderer(mTvVideoView)
            VideoConstants.setContentOfVideoView(mTvVideoView, participant: pParticipant)
            self.previousVideoTrack = lVideoTrack!
        }
    }
    
    private func removeRenderVideoTrack(_ pVideoTrak : VideoTrack?)
    {
        if let lVideoTrack = pVideoTrak,
           pVideoTrak is VideoRenderer {
            self.fullScrImageView.isHidden = true
            lVideoTrack.removeRenderer(pVideoTrak as! VideoRenderer)
            mTvVideoView.invalidateRenderer()
        }
    }
}

