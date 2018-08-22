//
//  SRVideoWriter.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/10.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

class SRViewWriter {
    
    public var duration : CGFloat{
        if let time = self.sourceTime{
            let s = CGFloat(CACurrentMediaTime() - time.seconds)
            return s > 0 ? s : 0
        }
        return 0
    }
    var sourceTime : CMTime?
    var writer : AVAssetWriter? = nil
    var videoInput : AVAssetWriterInput!
    var videoPixelAdaptor : AVAssetWriterInputPixelBufferAdaptor!
    var audioInput : AVAssetWriterInput!
    
    weak var view : UIView?
    init(view:UIView?) {
        self.view = view
    }
    
    //写入buffer
    var lastPixelTime : CMTime?
    func appendPixelBuffer(pixelBuffer:CVPixelBuffer,presentationTime:CMTime){
        guard let writer = self.writer,writer.status == .writing,self.videoInput.isReadyForMoreMediaData else {
            return
        }
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 100000)
        if let last = self.lastPixelTime{
            //如果两帧之间的间隔小于16ms 不添加
            if now.seconds - last.seconds < 0.016{
                print("视频帧间隔太短 return。。。")
                return
            }
        }
        self.lastPixelTime = now
        self.videoPixelAdaptor.append(pixelBuffer, withPresentationTime: now)
    }
    //写入音频
    var lastAudioTime : CMTime?
    func appendAudioSampleBuffer(buffer:CMSampleBuffer){
        guard let writer = self.writer,writer.status == .writing,self.audioInput.isReadyForMoreMediaData else {
            return
        }
        //从写下时间
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000)
        if let last = self.lastAudioTime{
            //如果两帧之间的间隔小于16ms 不添加
            if now.seconds - last.seconds < 0.016{
                print("音频帧间隔太短 return。。。")
                return
            }
        }
        self.lastAudioTime = now
        CMSampleBufferSetOutputPresentationTimeStamp(buffer, now)
        self.audioInput.append(buffer)
    }
    
}

extension SRViewWriter{
    func start(size:CGSize,url:URL) throws{
        guard let view = self.view else{return}
        let videoSettings = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : size.width * UIScreen.main.scale,
            AVVideoHeightKey : size.height * UIScreen.main.scale
            ] as [String : Any]
        self.videoInput = AVAssetWriterInput.init(mediaType: .video, outputSettings: videoSettings)
        self.videoInput.expectsMediaDataInRealTime = true
        self.videoPixelAdaptor = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: self.videoInput, sourcePixelBufferAttributes: nil)
        
        let config = AVOutputSettingsAssistant.init(preset: AVOutputSettingsPreset.preset1280x720)
        self.audioInput = AVAssetWriterInput.init(mediaType: .audio, outputSettings: config?.audioSettings)
        self.audioInput.expectsMediaDataInRealTime = true
        self.writer = try AVAssetWriter.init(outputURL: url, fileType: .mp4)
        self.writer?.add(self.videoInput)
        self.writer?.add(self.audioInput)
        print("startWriting:\(CACurrentMediaTime())")
        self.writer?.startWriting()
        print("startWriting end:\(CACurrentMediaTime())")
        //开始 退后0.1秒进入source 
        self.sourceTime = CMTimeMakeWithSeconds(CACurrentMediaTime() + 0.1, 1000000)
        self.writer?.startSession(atSourceTime: self.sourceTime!)
    }
    func stop(){
        self.sourceTime = nil
        self.writer?.endSession(atSourceTime: CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000))
        
        //做一次线程的休眠 直到finished writing
        let sem = DispatchSemaphore(value: 0)
        self.writer?.finishWriting {
            sem.signal()
        }
        _ = sem.wait(timeout: DispatchTime.distantFuture)
    }
}
