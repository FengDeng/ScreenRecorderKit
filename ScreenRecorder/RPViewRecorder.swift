//
//  RPViewRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

public var useAudioUnit = false

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
    let queue = DispatchQueue.init(label: "com.RPViewRecorder.buffer.queue", qos: DispatchQoS.userInteractive)
    
    var captureHandler: ((RPViewBuffer) -> Swift.Void)?
    func startCapture(view captureView:UIView, captureHandler: ((RPViewBuffer) -> Swift.Void)?){
        self.captureHandler = captureHandler
        self.viewCapture.startCapture(view: captureView, delegate: self)
        if useAudioUnit{
            self.micUnitCapture.startCapture(delegate: self)
        }else{
            self.micCapture.startCapture(delegate: self)
        }
    }
    
    func stopCapture(){
        self.viewCapture.stopCapture()
        if useAudioUnit{
            self.micUnitCapture.stopCapture()
        }else{
            self.micCapture.stopCapture()
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
