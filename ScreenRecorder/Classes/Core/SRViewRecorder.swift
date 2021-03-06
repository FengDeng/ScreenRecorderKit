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
    //提供视频流 暴露让外界设置是否截屏或者使用旧图片
    public var viewCapture : SRViewCapture
    //提供音频流
    public var micCapture : SRMicCapture
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
    public let flag : String
    /// init
    ///
    /// - Parameters:
    ///   - view: record view
    ///   - flag: 标志位 下次初始化传入相同的 可以续录
    public init(view:UIView,flag:String) {
        self.flag = flag
        self.directory = SRRecorderFileManager.default.directory(with: flag)

        self.view = view
        self.viewCapture = SRViewCapture.init(view: view)
        self.micCapture = SRMicCapture.init()
        self.writer = SRViewWriter.init(view: view)
        
        self.micCapture.delegate = self
        self.viewCapture.delegate = self
        self.queue.maxConcurrentOperationCount = 1
        self.setupExsit()
        SRViewRecorderException.default.append(recorder: self)
    }
}

public extension SRViewRecorder{
    public func start(){
        //获取一下需要录制的视图的宽高
        let size = self.view.bounds.size == CGSize.zero ? CGSize.init(width: 640, height: 540) : self.view.bounds.size
        //先检查下录音权限吧
        AVAudioSession.sharedInstance().requestRecordPermission { (succ) in
            if succ{
                let op = BlockOperation.init {[weak self] in
                    guard let `self` = self,!self.isRecording,self.maxDuration > self.duration else{return}
                    DispatchQueue.main.async {
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                    self.isRecording = true
                    self.viewCapture.start()
                    self.micCapture.start()
                    let file = self.directory + "/\(Int(Date().timeIntervalSince1970)).mp4"
                    try? FileManager.default.removeItem(atPath: file)
                    do{
                        try self.writer.start(size:size,url: URL.init(fileURLWithPath: file))
                    }catch{
                        print("writer error: \(error)")
                    }
                    DispatchQueue.main.async {[weak self] in
                        guard let `self` = self else{return}
                        self.delegate?.onViewRecorderStarted()
                    }
                    print("开始录制》》》》》》》》》》》》》")
                }
                op.queuePriority = .veryHigh//优先级最高
                self.queue.addOperation(op)
            }
        }
        
    }
    public func pause(){
        let op = BlockOperation.init {[weak self] in
            guard let `self` = self,self.isRecording else{return}
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            self.isRecording = false
            self.writer.stop()
            self.viewCapture.pause()
            self.micCapture.pause()
            self.setupExsit()
            print("暂停录制》》》》》》》》》》》》》")
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
        self._composition = AVMutableComposition.init()
        self.assets = SRRecorderFileManager.default.files(with: self.flag).map { (path) -> AVURLAsset in
            let asset = AVURLAsset.init(url: URL.init(fileURLWithPath: path))
            return asset
        }
        for asset in self.assets{
            do{
                try self._composition.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: asset, at: kCMTimeInvalid)
            }catch{
                print("\(asset):::\(error)")
            }
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
            print("exportSessionError:\(self.exportSession?.error)")
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

