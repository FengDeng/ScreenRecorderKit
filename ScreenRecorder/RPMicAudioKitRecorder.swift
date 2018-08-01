//
//  RPMicAudioKitRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/31.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AudioKit

protocol RPMicAudioKitRecorderDeleagte : class {
    func onMicAudioKitRecorderBuffer(buffer:CMSampleBuffer)
}

class RPMicAudioKitRecorder {
    
    let mic = AKMicrophone.init()
    var mixer : AKMixer!
    weak var delegate : RPMicAudioKitRecorderDeleagte?
    init() {
        AKSettings.bufferLength = .medium
        do {
            try AKSettings.setSession(category: .playAndRecord, with: .defaultToSpeaker)
        } catch {
            AKLog("Could not set session category.")
        }
        AKSettings.defaultToSpeaker = true
        mixer = AKMixer.init(mic)
        mixer.avAudioNode.installTap(onBus: 0, bufferSize: 1024, format: nil) {[weak self] (pcmbuffer, time) in
            self?.handleAudioPCMBuffer(pcmbuffer: pcmbuffer)
        }
    }
    
    
    func startCapture(delegate:RPMicAudioKitRecorderDeleagte?){
        self.delegate = delegate
        do{
            try AudioKit.start()
        }catch{
            print(error)
        }
    }
    
    func stopCapture(){
        do{
            try AudioKit.stop()
        }catch{
            print(error)
        }
    }
    
    func handleAudioPCMBuffer(pcmbuffer:AVAudioPCMBuffer){
        let samples = pcmbuffer.mutableAudioBufferList
        let audioFormat = pcmbuffer.format.streamDescription
        var format : CMFormatDescription? = nil
        let status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, audioFormat, 0, nil, 0, nil, nil, &format)
        if status != noErr{
            print(status.description)
        }
        var buffer : CMSampleBuffer? = nil
        var timing = CMSampleTimingInfo.init(duration: CMTimeMake(1, Int32(audioFormat.pointee.mSampleRate)), presentationTimeStamp: CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000), decodeTimeStamp: kCMTimeInvalid)
        let status1 = CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, format, CMItemCount(pcmbuffer.frameLength), 1, &timing, 0, nil, &buffer)
        if status1 != noErr{
            print("创建SampleBuffer:" + status1.description)
        }
        if let buffer = buffer{
            let status2 = CMSampleBufferSetDataBufferFromAudioBufferList(buffer, kCFAllocatorDefault, kCFAllocatorDefault, 0, samples)
            if status2 != noErr{
                print("添加SampleBuffer的Data:" + status2.description)
            }
            self.delegate?.onMicAudioKitRecorderBuffer(buffer: buffer)
        }
    }
}
