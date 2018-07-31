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
    public var view : UIView?
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
    let writeQueue = DispatchQueue.init(label: "com.screen.recorder.writer.queue", qos: DispatchQoS.userInteractive)
    let queue = DispatchQueue.init(label: "com.screen.recorder.queue", qos: DispatchQoS.userInteractive)
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
    var canReceiveBuffer = false //是否可以接受流 此处以收到视频首帧为准
}

extension ScreenRecorder{
    //开始录制
    public func start(){
        self.queue.sync {[weak self] in
            guard let `self` = self,!self.isRecording else{return}
            //正在录制中 返回
            self.isRecording = true
            do{
                //新建文件 初始化writer
                let url = self.folder + "/\(self.paths.count + 1).mp4"
                print("新建文件：\(url)")
                self.paths.append(url)
                self.writer = try AVAssetWriter.init(url: URL.init(fileURLWithPath: url), fileType: AVFileType.mp4)
                if self.writer!.canAdd(self.videoInput){
                    self.writer?.add(self.videoInput)
                }
                if self.writer!.canAdd(self.audioInput){
                    self.writer?.add(self.audioInput)
                }
                //开启屏幕录制
                self.viewRecorder.startCapture(view: self.view ?? UIApplication.shared.keyWindow!, captureHandler: {[weak self] (bufferType) in
                    //注意 这里的数据是从另一个线程过来的
                    guard let `self` = self else{return}
                    //到我们自己的线程中操作变量
                    self.queue.sync {[weak self] in
                        guard let `self` = self,self.isRecording else{return}
                        switch bufferType{
                        case .audio(let buffer):
                            if self.canReceiveBuffer && self.isRecording && self.audioInput.isReadyForMoreMediaData{
                                self.appendAudioBuffer(buffer: buffer)
                            }
                            break
                        case .video(let buffer):
                            //视频首帧到达 开启writer
                            if !self.canReceiveBuffer{
                                self.canReceiveBuffer = true
                                let a = CACurrentMediaTime()
                                print("首帧到达")
                                self.writer?.startWriting()
                                print("startWriting耗时:\(CACurrentMediaTime() - a)")
                                self.startSourceTime = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
                                self.writer?.startSession(atSourceTime: self.startSourceTime!)
                            }
                            if self.canReceiveBuffer && self.isRecording && self.videoInput.isReadyForMoreMediaData{
                                self.appendVideoPixelBuffer(buffer: buffer)
                            }
                            break
                        }
                    }
                })
            }catch{
                
            }
        }
    }
    
    //暂停录制
     public func pause(){
        self.queue.sync {[weak self] in
            guard let `self` = self, self.isRecording,self.canReceiveBuffer else{return}
            self.isRecording = false
            self.viewRecorder.stopCapture()
            self.canReceiveBuffer = false
            let a = CACurrentMediaTime()
            self.writer?.finishWriting(completionHandler: {[weak self] in
                //录制好一个文件，写入compostion
                print("finishWriting耗时:\(CACurrentMediaTime() - a)")
                print(">>>>>>>>暂停成功")
                
                self?.copositionAllFiles()
            })
        }
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
    
    fileprivate func appendAudioBuffer(buffer:CMSampleBuffer){
        self.writeQueue.sync {[weak self] in
            guard let `self` = self else{return}
            let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
            if let start = self.startSourceTime{
                self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
            }
            CMSampleBufferSetOutputPresentationTimeStamp(buffer, now)
            self.audioInput.append(buffer)
        }
    }
    fileprivate func appendVideoPixelBuffer(buffer:CVPixelBuffer){
        self.writeQueue.sync {[weak self] in
            guard let `self` = self else{return}
            let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
            if let start = self.startSourceTime{
                self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds - start.seconds + now.seconds))
            }
            self.videoAdaptor.append(buffer, withPresentationTime: now)
        }
    }
    
    func copositionAllFiles(){
        self.compositon = AVMutableComposition.init()
        for path in self.paths{
            let asset = AVURLAsset.init(url: URL.init(fileURLWithPath: path))
            
            do {
                /*
                let sub = CMTimeSubtract(asset.duration, CMTimeMake(5, 30))
                try self.compositon.insertTimeRange(CMTimeRangeMake(CMTimeMake(5, 30), sub), of: asset, at: kCMTimeInvalid)*/
                
                try self.compositon.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: asset, at: kCMTimeInvalid)
            } catch  {
                print(error)
            }
        }
        self.delegate?.onScreenRecorderProgress(second: CGFloat(self.compositon.duration.seconds))
    }
    
}
