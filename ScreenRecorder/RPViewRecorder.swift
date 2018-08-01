//
//  RPViewRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

public var useAudioType = 2 //AVCaptureSession 0 //unit `1 //audiokit 2

enum RPViewBuffer{
    case video(CVPixelBuffer)
    case audio(CMSampleBuffer)
}
class RPViewRecorder {
    
    static let shared = RPViewRecorder()
    init() {
    }
    var isMicrophoneEnabled = false
    
    let viewCapture = RPViewVideoRecorder()
    let micCapture = RPMicAudioRecorder()
    let micUnitCapture = RPMicAudioUnitRecorder.init()
    let micKitCapture = RPMicAudioKitRecorder.init()
    let queue = DispatchQueue.init(label: "com.RPViewRecorder.buffer.queue", qos: DispatchQoS.userInteractive)
    
    var captureHandler: ((RPViewBuffer) -> Swift.Void)?
    func startCapture(view captureView:UIView, captureHandler: ((RPViewBuffer) -> Swift.Void)?){
        self.captureHandler = captureHandler
        self.viewCapture.startCapture(view: captureView, delegate: self)
        if useAudioType == 0{
            self.micCapture.startCapture(delegate: self)
        }else if useAudioType == 1{
            self.micUnitCapture.startCapture(delegate: self)
        }else{
            self.micKitCapture.startCapture(delegate: self)
        }
    }
    
    func stopCapture(){
        self.viewCapture.stopCapture()
        if useAudioType == 0{
            self.micCapture.stopCapture()
        }else if useAudioType == 1{
            self.micUnitCapture.stopCapture()
        }else{
            self.micKitCapture.stopCapture()
        }
    }
    
    
}

extension RPViewRecorder : RPViewVideoRecorderDelegate{
    func onViewVideoRecorderBuffer(buffer: CVPixelBuffer) {
        self.queue.async {[weak self] in
            self?.captureHandler?(RPViewBuffer.video(buffer))
        }
    }
    
    
}
extension RPViewRecorder : RPMicAudioRecorderDelegate{
    func onMicAudioRecorderBuffer(buffer: CMSampleBuffer) {
        self.queue.async {[weak self] in
            self?.captureHandler?(RPViewBuffer.audio(buffer))
        }
    }
}
extension RPViewRecorder : RPMicAudioUnitRecorderDeleagte{
    func onMicAudioUnitRecorderBuffer(buffer: CMSampleBuffer) {
        self.queue.async {[weak self] in
            self?.captureHandler?(RPViewBuffer.audio(buffer))
        }
    }
}

extension RPViewRecorder : RPMicAudioKitRecorderDeleagte{
    func onMicAudioKitRecorderBuffer(buffer: CMSampleBuffer) {
        self.queue.async {[weak self] in
            self?.captureHandler?(RPViewBuffer.audio(buffer))
        }
    }
}
