//
//  SRMicCapture.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/10.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

protocol SRMicCaptureDelegate: class {
    func onMicCaptureSampleBuffer(buffer:CMSampleBuffer)
}
/// 获取mic 用前置mic录音 后置mic降噪
class SRMicCapture : NSObject{
    public weak var delegate : SRMicCaptureDelegate?
    fileprivate let queue = DispatchQueue.init(label: "com.SRMicCapture.queue")
    lazy var session : AVCaptureSession = {
        let session = AVCaptureSession.init()
        let audioDevice = AVCaptureDevice.default(for: .audio)
        let input = try? AVCaptureDeviceInput.init(device: audioDevice!)
        session.addInput(input!)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: self.queue)
        session.addOutput(output)
        return session
    }()
    
    public override init() {
        super.init()
    }
    public func start(){
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch  {
            print("SRMicCapture start:\(error.localizedDescription)")
        }
        self.session.startRunning()
    }
    public func pause(){
        self.session.stopRunning()
    }
}

extension SRMicCapture : AVCaptureAudioDataOutputSampleBufferDelegate{
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.delegate?.onMicCaptureSampleBuffer(buffer: sampleBuffer)
    }
}
