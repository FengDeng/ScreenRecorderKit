//
//  ScreenRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/26.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import ReplayKit


public protocol ScreenRecorderDelegate : class {
    func onScreenRecorderProgress(second:CGFloat)
    func onScreenRecorderGenerate(outFilePath:String)
    func onScreenRecorderError(error:Error)
    func onScreenRecorderCompositionChanged(composition:AVMutableComposition)
}

public class ScreenRecorder{
    public static let `default` = ScreenRecorder()
    weak var delegate : ScreenRecorderDelegate?
    var paths = [String]() //录制的MP4地址
    lazy var folder : String = {
        let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,FileManager.SearchPathDomainMask.userDomainMask, true)
        return documentPaths[0] + "/ScreenRecorder"
    }()
    var videoAdaptor : AVAssetWriterInputPixelBufferAdaptor!
    init() {
        //没有文件夹  新建
        if !FileManager.default.fileExists(atPath: folder){
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
        //获取所有录制好的文件地址
        if let paths = FileManager.default.subpaths(atPath: folder)?.sorted(){
            self.paths = paths.map({ (str) -> String in
                return self.folder + "/" + str
            })
            print("初始化目录文件:\(self.paths)")
            //创建compostion
            self.copositionAllFiles()
        }
        //
        self.videoAdaptor = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: self.videoInput, sourcePixelBufferAttributes: nil)
        //崩溃检测
    }
    
    //录制
    var viewRecorder = RPViewRecorder.init()
    let queue = DispatchQueue.init(label: "com.screen.recorder.queue")
    var writer : AVAssetWriter?
    private(set) var isRecording: Bool = false
    lazy var videoInput : AVAssetWriterInput = {
        let config = AVOutputSettingsAssistant.init(preset: AVOutputSettingsPreset.preset1280x720)
        let input = AVAssetWriterInput.init(mediaType: .video, outputSettings: config?.videoSettings)
        input.expectsMediaDataInRealTime = true
        return input
    }()
    lazy var audioInput : AVAssetWriterInput = {
        let config = AVOutputSettingsAssistant.init(preset: AVOutputSettingsPreset.preset1280x720)
        let input = AVAssetWriterInput.init(mediaType: .audio, outputSettings: config?.audioSettings)
        input.expectsMediaDataInRealTime = true
        return input
    }()
    
    //媒体
    var compositon = AVMutableComposition.init()
    var exportSession : AVAssetExportSession? = nil
    var startSourceTime : CMTime?
}

extension ScreenRecorder{
    //开始录制
    public func start(){
        if self.isRecording{return}
        self.queue.sync {
            self.isRecording = true
        }
        print("开始录制")
        do {
            //新建文件
            let url = self.folder + "/\(self.paths.count + 1).mp4"
            self.paths.append(url)
            print(url)
            self.writer = try AVAssetWriter.init(url: URL.init(fileURLWithPath: url), fileType: AVFileType.mp4)
            if self.writer!.canAdd(self.videoInput){
                self.writer?.add(self.videoInput)
            }
            if self.writer!.canAdd(self.audioInput){
                self.writer?.add(self.audioInput)
            }
        } catch  {
            print("writer init:\(String(describing: writer?.error))")
        }
        
        if #available(iOS 32.0, *) {
            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().startCapture(handler: { (buffer, bufferType, error) in
                self.queue.sync {
                    //接收到buffer数据 如果没有开始写入 则开始
                    let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
                    if let start = self.startSourceTime{
                        self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
                    }
                    
                    switch bufferType{
                    case .video:
                        self.appendVideoBuffer(buffer: buffer)
                        break
                    case .audioMic:
                        self.appendAudioBuffer(buffer: buffer)
                        break
                    case .audioApp:
                        break
                    }
                }
            }) { (error) in
                
            }
        } else {
            // Fallback on earlier versions
            self.viewRecorder.startCapture(view: UIApplication.shared.keyWindow!) { (bufferType) in
                self.queue.sync {
                    switch bufferType{
                    case .audio(let buffer):
                        self.appendAudioBuffer(buffer: buffer)
                        break
                    case .video(let buffer):
                        self.appendVideoPixelBuffer(buffer: buffer)
                        break
                    }
                }
            }
        }
        self.writer?.startWriting()
        self.startSourceTime = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
        self.writer?.startSession(atSourceTime: self.startSourceTime!)
    }
    
    //暂停录制
     public func pause(){
        if !self.isRecording{return}
        self.queue.sync {
            self.isRecording = false
        }
        if #available(iOS 32.0, *) {
            RPScreenRecorder.shared().stopCapture { (err) in }
        } else {
            // Fallback on earlier versions
            self.viewRecorder.stopCapture()
        }
        self.writer?.finishWriting(completionHandler: {[weak self] in
            //录制好一个文件，写入compostion
            print("暂停成功")
            self?.copositionAllFiles()
        })
        
       
    }
    
    //清除缓存
    public func clear(){
        if self.isRecording{return}
        for path in self.paths{
            try? FileManager.default.removeItem(atPath: path)
        }
        self.paths = [String]()
        self.copositionAllFiles()
    }
    
    //删除最后一段
    public func deleteLast(){
        if self.isRecording || self.paths.count == 0{return}
        //获取最后
        let last = self.paths.removeLast()
        try? FileManager.default.removeItem(atPath: last)
        self.copositionAllFiles()
    }
    
    //合成视频
    public func generate(outFilePath:String){
        if self.isRecording{return}
        self.copositionAllFiles()
        try? FileManager.default.removeItem(atPath: outFilePath)
        self.exportSession = AVAssetExportSession.init(asset: self.compositon.copy() as! AVComposition, presetName: AVAssetExportPreset1280x720)
        self.exportSession?.outputURL = URL.init(fileURLWithPath: outFilePath)
        self.exportSession?.outputFileType = AVFileType.mp4
        self.exportSession?.exportAsynchronously {[weak self] in
            print("合成成功:\(outFilePath)")
            self?.delegate?.onScreenRecorderGenerate(outFilePath: outFilePath)
        }
    }
}

extension ScreenRecorder{
    
    func appendAudioBuffer(buffer:CMSampleBuffer){
        guard self.isRecording,self.audioInput.isReadyForMoreMediaData else{return}
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
        if let start = self.startSourceTime{
            self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
        }
        CMSampleBufferSetOutputPresentationTimeStamp(buffer, now)
        print("audioMic:\(CMSampleBufferGetPresentationTimeStamp(buffer).seconds)")
        self.audioInput.append(buffer)
    }
    func appendVideoBuffer(buffer:CMSampleBuffer){
        guard self.isRecording,self.videoInput.isReadyForMoreMediaData else{return}
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
        if let start = self.startSourceTime{
            self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
        }
        CMSampleBufferSetOutputPresentationTimeStamp(buffer, now)
        print("video:\(CMSampleBufferGetPresentationTimeStamp(buffer).seconds)")
        self.videoInput.append(buffer)
    }
    func appendVideoPixelBuffer(buffer:CVPixelBuffer){
        guard self.isRecording,self.videoInput.isReadyForMoreMediaData else{return}
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
        if let start = self.startSourceTime{
            self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
        }
        print("video:\(now.seconds)")
        self.videoAdaptor.append(buffer, withPresentationTime: now)
    }
    
    func copositionAllFiles(){
        self.compositon = AVMutableComposition.init()
        /*
        let audioCompositionTrack = self.compositon.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoCompositionTrack = self.compositon.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        var videoTimeRanges = [NSValue]()
        var audioTimeRanges = [NSValue]()
        var videoTracks = [AVAssetTrack]()
        var audioTracks = [AVAssetTrack]()
        var isOr = true*/
        for path in self.paths{
            let asset = AVURLAsset.init(url: URL.init(fileURLWithPath: path))
            
            do {
                let sub = CMTimeSubtract(asset.duration, CMTimeMake(10, 30))
                try self.compositon.insertTimeRange(CMTimeRangeMake(CMTimeMake(10, 30), sub), of: asset, at: kCMTimeInvalid)
            } catch  {
                print(error)
            }
            
            /*
            let audioAssetTrack = asset.tracks(withMediaType: .audio).first
            let videoAssetTrack = asset.tracks(withMediaType: .video).first
            videoTimeRanges.append(NSValue.init(timeRange: CMTimeRangeMake(kCMTimeZero, asset.duration)))
            audioTimeRanges.append(NSValue.init(timeRange: CMTimeRangeMake(kCMTimeZero, asset.duration)))
            videoTracks.append(videoAssetTrack!)
            audioTracks.append(audioAssetTrack!)
            
            if isOr{
                videoCompositionTrack?.preferredTransform = (videoAssetTrack?.preferredTransform)!
                isOr = false
            }*/
            /*
            try? audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioAssetTrack!, at: kCMTimeInvalid)
            try? videoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoAssetTrack!, at: kCMTimeInvalid)*/
        }
        /*
        do{
            try audioCompositionTrack?.insertTimeRanges(audioTimeRanges, of: audioTracks, at: kCMTimeInvalid)
            try videoCompositionTrack?.insertTimeRanges(videoTimeRanges, of: videoTracks, at: kCMTimeInvalid)
        }catch{
            print(error)
        }*/
        
        self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds))
    }
    
}
