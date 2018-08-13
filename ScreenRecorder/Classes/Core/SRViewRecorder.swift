//
//  SRViewRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/10.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import UIKit
import AVKit

public protocol SRViewRecorderDelegate : class {
    func onViewRecorderPaused()
    func onViewRecorderStarted()
    func onViewRecorderPartsChanged(assets:[AVURLAsset])//录制完成一个 录制开始时并不改变
    func onViewRecorderProgressing(seconds:CGFloat)
    func onViewRecorderError(error:Error)
}

public class SRViewRecorder{
    //操作队列 负责串联执行开始 暂停 写入等操作
    fileprivate let queue = OperationQueue.init()
    //提供视频流
    fileprivate var viewCapture : SRViewCapture
    //提供音频流
    fileprivate var micCapture : SRMicCapture
    //负责把音频流视频流写成文件
    fileprivate var writer : SRViewWriter
    //音视频片段资源管理
    fileprivate var _composition = AVMutableComposition()
    //合并片段
    fileprivate var exportSession : AVAssetExportSession? = nil
    //合成片段定时器
    fileprivate var exportTimer : Timer? = nil
    //合成进度回调
    fileprivate var exportProgress : ((CGFloat)->Void)?
    
    //暴露给外界播放
    public var composition : AVComposition{
        return self._composition.copy() as! AVComposition
    }
    //是否正在录制
    public private(set) var isRecording = false
    //当前录制时间
    public var duration : CGFloat{
        return CGFloat(self.composition.duration.seconds) + self.writer.duration
    }
    //录制最长时间
    public var maxDuration : CGFloat = CGFloat.greatestFiniteMagnitude
    //事件回调
    public weak var delegate : SRViewRecorderDelegate?
    //分片录制地址
    public let directory : String //文件夹地址
    //分片asset
    public private(set) var assets = [AVURLAsset]()
    //录制的view
    public let view : UIView
    /// init
    ///
    /// - Parameters:
    ///   - view: record view
    ///   - folderName: store recorded file
    public init(view:UIView,folderName:String) {
        let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,FileManager.SearchPathDomainMask.userDomainMask, true)
        self.directory = documentPaths[0] + "/SRViewRecorder/" + folderName
        if !FileManager.default.fileExists(atPath: self.directory){
            try? FileManager.default.createDirectory(atPath: self.directory, withIntermediateDirectories: true, attributes: nil)
        }
        self.view = view
        self.viewCapture = SRViewCapture.init(view: view)
        self.micCapture = SRMicCapture.init()
        self.writer = SRViewWriter.init(width: view.bounds.width, height: view.bounds.height)
        
        self.micCapture.delegate = self
        self.viewCapture.delegate = self
        self.queue.maxConcurrentOperationCount = 1
        self.setupExsit()
        SRViewRecorderException.default.append(recorder: self)
    }
}

public extension SRViewRecorder{
    public func start(){
        //先检查下录音权限吧
        AVAudioSession.sharedInstance().requestRecordPermission { (succ) in
            if succ{
                let op = BlockOperation.init {[weak self] in
                    guard let `self` = self,!self.isRecording,self.maxDuration > self.duration else{return}
                    self.isRecording = true
                    self.viewCapture.start()
                    self.micCapture.start()
                    let file = self.directory + "/\(Int(Date().timeIntervalSince1970)).mp4"
                    try? self.writer.start(url: URL.init(fileURLWithPath: file))
                    DispatchQueue.main.async {[weak self] in
                        guard let `self` = self else{return}
                        self.delegate?.onViewRecorderStarted()
                    }
                }
                op.queuePriority = .veryHigh//优先级最高
                self.queue.addOperation(op)
            }
        }
        
    }
    public func pause(){
        let op = BlockOperation.init {[weak self] in
            guard let `self` = self,self.isRecording else{return}
            self.isRecording = false
            self.writer.stop()
            self.viewCapture.pause()
            self.micCapture.pause()
            self.setupExsit()
        }
        op.queuePriority = .veryHigh//优先级最高
        self.queue.addOperation(op)
    }
    
    public func deleteLast(){
        self.queue.addOperation {[weak self] in
            guard let `self` = self,self.assets.count > 0 else{return}
            let asset = self.assets.removeLast()
            try? FileManager.default.removeItem(at: asset.url)
            self.setupExsit()
        }
    }
    public func deleteAll(){
        self.queue.addOperation {[weak self] in
            guard let `self` = self else{return}
            for asset in self.assets{
                do{
                    try FileManager.default.removeItem(at: asset.url)
                }catch{
                    print(error)
                }
            }
            self.setupExsit()
        }
    }
}

extension SRViewRecorder{
    //设置已经存在的
    fileprivate func setupExsit(){
        do {
            self._composition = AVMutableComposition.init()
            let files = try FileManager.default.subpathsOfDirectory(atPath: self.directory)
            self.assets = files.sorted(by: { (path1, path2) -> Bool in
                if let filename1 = path1.components(separatedBy: "/").last?.components(separatedBy: ".").first,let filename2 = path2.components(separatedBy: "/").last?.components(separatedBy: ".").first{
                    return (Int(filename1) ?? 0) < (Int(filename2) ?? 0)
                }
                return true
            }).map { (path) -> AVURLAsset in
                let asset = AVURLAsset.init(url: URL.init(fileURLWithPath: self.directory + "/" + path))
                return asset
            }
            for asset in self.assets{
                try self._composition.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: asset, at: kCMTimeInvalid)
            }
        } catch  {
            print(error)
        }
        DispatchQueue.main.async {[weak self] in
            guard let `self` = self else{return}
            let sec = CGFloat(self._composition.duration.seconds)
            self.delegate?.onViewRecorderProgressing(seconds: sec > self.maxDuration ? self.maxDuration : sec)
            self.delegate?.onViewRecorderPartsChanged(assets: self.assets)
            self.delegate?.onViewRecorderPaused()
        }
    }
    
    public func combineParts(exportFilePath:String,exportProgress:((CGFloat)->Void)?,completed:((Error?)->Void)?){
        if self.isRecording{return}
        self.exportProgress = exportProgress
        self.exportSession = AVAssetExportSession.init(asset: self.composition, presetName: AVAssetExportPresetHighestQuality)
        self.exportSession?.outputURL = URL.init(fileURLWithPath: exportFilePath)
        self.exportSession?.outputFileType = .mp4
        self.exportTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(exportProgressHandle), userInfo: nil, repeats: true)
        self.exportTimer?.fire()
        self.exportSession?.exportAsynchronously {[weak self] in
            guard let `self` = self else{return}
            self.exportTimer?.invalidate()
            self.exportTimer = nil
            completed?(self.exportSession?.error)
        }

    }
    @objc private func exportProgressHandle(){
        if let progress = self.exportSession?.progress{
            self.exportProgress?(CGFloat(progress))
        }
    }
}

extension SRViewRecorder : SRViewCaptureDelegate,SRMicCaptureDelegate{
    public func onViewCapturePixelBuffer(buffer: CVPixelBuffer,time:CMTime) {
        self.queue.addOperation {[weak self] in
            guard let `self` = self,self.isRecording else{return}
            //异步到主线程去回调录制progress
            DispatchQueue.main.async {[weak self] in
                guard let `self` = self else{return}
                //超过最大时间 结束
                if self.duration >= self.maxDuration{
                    self.pause()
                    return
                }else{
                    self.delegate?.onViewRecorderProgressing(seconds: self.duration)
                }
                
            }
            self.writer.appendPixelBuffer(pixelBuffer: buffer,presentationTime:time)
        }
    }
    public func onMicCaptureSampleBuffer(buffer: CMSampleBuffer) {
        self.queue.addOperation {[weak self] in
            guard let `self` = self,self.isRecording else{return}
            self.writer.appendAudioSampleBuffer(buffer: buffer)
        }
    }
}

