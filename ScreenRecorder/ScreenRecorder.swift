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
    func onScreenRecorderGenerateProgress(progress:CGFloat)
    func onScreenRecorderGenerateCompleted(outFilePath:String)
    func onScreenRecorderError(error:Error)
}

public class ScreenRecorder{
    //sigle
    public static let `default` = ScreenRecorder()
    //delegate
    public weak var delegate : ScreenRecorderDelegate?
    //record view
    public var view : UIView?
    //use avplayitem play this
    public var composition : AVComposition{
        return self._compositon.copy() as! AVComposition
    }
    //duration
    public var duration : CGFloat{
        return CGFloat(self._compositon.duration.seconds)
    }
    //is recording
    public var isRecording : Bool{
        return self._isRecording
    }
    //最大的录制时长 单位s
    public var maxDuration : CGFloat = 15
    
    
    
    var paths = [String]() //录制的MP4地址
    var videoAdaptor : AVAssetWriterInputPixelBufferAdaptor!
    //以一个地址初始化
    let folder : String
    public init(directory : String? = nil) {
        //没有文件夹  新建
        if let di = directory{
            self.folder = di + "/ScreenRecorder"
        }else{
            let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,FileManager.SearchPathDomainMask.userDomainMask, true)
            self.folder = documentPaths[0] + "/ScreenRecorder"
        }
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
    let writeQueue = DispatchQueue.init(label: "com.screen.recorder.writer.queue")
    let queue = DispatchQueue.init(label: "com.screen.recorder.queue")
    var writer : AVAssetWriter?
    private(set) var _isRecording: Bool = false
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
    var _compositon = AVMutableComposition.init()
    var exportSession : AVAssetExportSession? = nil
    var startSourceTime : CMTime? //标记writer的写入时间。
    var canReceiveBuffer = false //是否可以接受流 此处以收到视频首帧为准
    
    var timer : Timer? = nil//合成视频 获取进度使用
}

extension ScreenRecorder{
    //开始录制
    public func start(){
        self.queue.sync {[weak self] in
            guard let `self` = self,!self._isRecording,self.duration < self.maxDuration else{return}
            self._isRecording = true
            //新建文件
            let url = self.folder + "/\(self.paths.count + 1).mp4"
            try? FileManager.default.removeItem(atPath: url)
            print("新建文件：\(url)")
            self.paths.append(url)
            do{
                //初始化writer
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
                        guard let `self` = self,self._isRecording else{return}
                        switch bufferType{
                        case .audio(let buffer):
                            if self.canReceiveBuffer && self._isRecording && self.audioInput.isReadyForMoreMediaData{
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
                            if self.canReceiveBuffer && self._isRecording && self.videoInput.isReadyForMoreMediaData{
                                self.appendVideoPixelBuffer(buffer: buffer)
                            }
                            break
                        }
                    }
                })
            }catch{
                print( "ScreenRecorder start" + error.localizedDescription)
            }
        }
    }
    
    //暂停录制
    public func pause(){
        self.queue.sync {[weak self] in
            guard let `self` = self, self._isRecording,self.canReceiveBuffer else{return}
            self._pause()
        }
    }
    
    fileprivate func _pause(){
        self._isRecording = false
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
    
    //清除缓存
    public func clear(){
        if self._isRecording{return}
        for path in self.paths{
            try? FileManager.default.removeItem(atPath: path)
        }
        self.paths = [String]()
        self.copositionAllFiles()
    }
    
    //删除最后一段
    public func deleteLast(){
        if self._isRecording || self.paths.count == 0{return}
        //获取最后
        let last = self.paths.removeLast()
        try? FileManager.default.removeItem(atPath: last)
        self.copositionAllFiles()
    }
    
    //合成视频
    public func generate(outFilePath:String){
        if self._isRecording{return}
        self.copositionAllFiles()
        try? FileManager.default.removeItem(atPath: outFilePath)
        self.exportSession = AVAssetExportSession.init(asset: self._compositon.copy() as! AVComposition, presetName: AVAssetExportPreset1280x720)
        self.exportSession?.outputURL = URL.init(fileURLWithPath: outFilePath)
        self.exportSession?.outputFileType = AVFileType.mp4
        //启动一个time 获取导出进度
        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(exportProgress), userInfo: nil, repeats: true)
        self.timer?.fire()
        self.exportSession?.exportAsynchronously {[weak self] in
            print("合成成功:\(outFilePath)")
            self?.timer?.invalidate()
            self?.timer = nil
            self?.delegate?.onScreenRecorderGenerateProgress(progress: 1)
            self?.delegate?.onScreenRecorderGenerateCompleted(outFilePath: outFilePath)
        }
    }
    
    @objc func exportProgress(){
        if let progress = self.exportSession?.progress{
            self.delegate?.onScreenRecorderGenerateProgress(progress: CGFloat(progress))
        }
    }
}

extension ScreenRecorder{
    
    fileprivate func appendAudioBuffer(buffer:CMSampleBuffer){
        self.writeQueue.sync {[weak self] in
            guard let `self` = self else{return}
            let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
            //            if let start = self.startSourceTime{
            //                self.delegate?.onScreenRecorderProgress(second: CGFloat(self._compositon.duration.seconds - start.seconds + now.seconds))
            //            }
            CMSampleBufferSetOutputPresentationTimeStamp(buffer, now)
            self.audioInput.append(buffer)
        }
    }
    fileprivate func appendVideoPixelBuffer(buffer:CVPixelBuffer){
        self.writeQueue.sync {[weak self] in
            guard let `self` = self else{return}
            let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
            if let start = self.startSourceTime{
                let time = self._compositon.duration.seconds - start.seconds + now.seconds - CMTimeMake(10, 30).seconds
                let second : CGFloat = time > 0 ? CGFloat(time) : 0
                if second >= self.maxDuration{
                    self._pause()
                    return
                }
                self.delegate?.onScreenRecorderProgress(second: second)
            }
            self.videoAdaptor.append(buffer, withPresentationTime: now)
        }
    }
    
    fileprivate func copositionAllFiles(){
        self._compositon = AVMutableComposition.init()
        for path in self.paths{
            let asset = AVURLAsset.init(url: URL.init(fileURLWithPath: path))
            
            do {
                //防止视频拼接处白屏。视频前后0.15秒被截掉
                let sub = CMTimeSubtract(asset.duration, CMTimeMake(10, 30))
                try self._compositon.insertTimeRange(CMTimeRangeMake(CMTimeMake(5, 30), sub), of: asset, at: kCMTimeInvalid)
                //try self._compositon.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: asset, at: kCMTimeInvalid)
            } catch  {
                print(error)
            }
        }
        if self.duration > self.maxDuration{
            self.delegate?.onScreenRecorderProgress(second: self.maxDuration)
        }else{
            self.delegate?.onScreenRecorderProgress(second: CGFloat(self._compositon.duration.seconds))
        }
        
    }
    
}
