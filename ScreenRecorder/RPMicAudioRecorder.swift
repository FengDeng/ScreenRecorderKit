//
//  RPMicAudioRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

protocol RPMicAudioRecorderDelegate : class {
    func onMicAudioRecorderBuffer(buffer:CMSampleBuffer)
}
class RPMicAudioRecorder : NSObject {
    let queue = DispatchQueue.init(label: "com.RPMicAudioRecorder.queue")
    let session : AVCaptureSession
    weak var delegate : RPMicAudioRecorderDelegate?
    override init() {
        self.session = AVCaptureSession.init()
        super.init()
        let audioDevice = AVCaptureDevice.default(for: .audio)
        let input = try? AVCaptureDeviceInput.init(device: audioDevice!)
        session.addInput(input!)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: self.queue)
        session.addOutput(output)
    }
    
    func startCapture(delegate:RPMicAudioRecorderDelegate){
        self.delegate = delegate
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch  {
            print("RPMicAudioRecorder startCapture:\(error.localizedDescription)")
        }
        self.session.startRunning()
    }
    func stopCapture(){
        self.session.stopRunning()
    }
    
}
extension RPMicAudioRecorder : AVCaptureAudioDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.delegate?.onMicAudioRecorderBuffer(buffer: sampleBuffer)
    }
}
