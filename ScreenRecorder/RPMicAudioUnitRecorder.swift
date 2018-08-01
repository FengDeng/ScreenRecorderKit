//
//  RPMicAudioUnitRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AudioUnit
import AVKit

protocol RPMicAudioUnitRecorderDeleagte : class {
    func onMicAudioUnitRecorderBuffer(buffer:CMSampleBuffer)
}

fileprivate let SampleRate : Double = 44100.0
fileprivate let ChannelCount = 1
class RPMicAudioUnitRecorder{
    
    weak var delegate : RPMicAudioUnitRecorderDeleagte?
    var audioUnit : AUAudioUnit?
    init() {
//        self.setupAudioSession()
//        self.setupAudioUnit()
    }
    
    func setupAudioSession(){
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try AVAudioSession.sharedInstance().setPreferredSampleRate(48000)
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.0053)//0.0053
            try AVAudioSession.sharedInstance().setActive(true)
        } catch  {
            print("setupAudioSession:\(error.localizedDescription)")
        }
    }
    
    func setupAudioUnit(){
        do {
            var desc = AudioComponentDescription.init()
            desc.componentType = kAudioUnitType_Output
            desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO
            desc.componentManufacturer = kAudioUnitManufacturer_Apple
            desc.componentFlags = 0
            desc.componentFlagsMask = 0
            

            
            
            
            self.audioUnit = try AUAudioUnit.init(componentDescription: desc, options: AudioComponentInstantiationOptions())
            //let hardwareFormat = self.audioUnit!.outputBusses[0].format
            let format = AVAudioFormat.init(standardFormatWithSampleRate: 48000, channels: 1)!
            /*
            for index in 0..<self.audioUnit!.outputBusses.count{
                let bus = self.audioUnit!.outputBusses[index]
                try bus.setFormat(format)
            }*/
            try self.audioUnit!.outputBusses[1].setFormat(format)
            
            /*
            //mixer unit
            let mixerDesc = AudioComponentDescription.init(componentType: kAudioUnitType_Mixer, componentSubType: kAudioUnitSubType_MultiChannelMixer, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
            let mixerAudioUnit = try AUAudioUnit.init(componentDescription: mixerDesc)
            for index in 0..<mixerAudioUnit.outputBusses.count{
                let bus = mixerAudioUnit.outputBusses[index]
                try bus.setFormat(format)
            }
            try mixerAudioUnit.outputBusses.setBusCount(2)
            for index in 0..<mixerAudioUnit.inputBusses.count{
                let bus = mixerAudioUnit.inputBusses[index]
                try bus.setFormat(format)
            }*/
            
            //render block
            let callback : AURenderPullInputBlock =  {[weak self]( flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                ts: UnsafePointer<AudioTimeStamp>,
                fc: AUAudioFrameCount,
                bus: Int,
                rawBuff: UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus
                in
                
                if let render = self?.audioUnit?.renderBlock{
                    let err = render(flags,ts,fc,1,rawBuff,nil)
                    if err == noErr{
                        self?.handleAudioSamples(samples: rawBuff, numberOfFrames: Int(fc))
                    }else{
                        print("render audio :\(err)")
                    }
                }
                return noErr
            }
            self.audioUnit?.outputProvider = callback
            
            self.audioUnit?.inputHandler = {[weak self] (actionFlags, timestamp, frameCount, inputBusNumber) in
                print("inputHandler called")
            }
            try self.audioUnit?.allocateRenderResources()
        } catch  {
            print(error)
        }
    }
    
    func startCapture(delegate:RPMicAudioUnitRecorderDeleagte?){
        self.delegate = delegate
        do {
            self.setupAudioSession()
            self.setupAudioUnit()
            try audioUnit?.startHardware()
        } catch  {
            print(error)
        }
    }
    func stopCapture(){
        audioUnit?.stopHardware()
    }
    
    lazy var audioFormat : AudioStreamBasicDescription = {
        var format = AudioStreamBasicDescription.init()
        format.mSampleRate = 48000
        format.mFormatID = kAudioFormatLinearPCM
        format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved
        format.mBytesPerPacket = 2
        format.mFramesPerPacket = 1
        format.mBytesPerFrame = 2
        format.mChannelsPerFrame = 1
        format.mBitsPerChannel = 16
        return format
    }()
    func handleAudioSamples(samples:UnsafeMutablePointer<AudioBufferList>,numberOfFrames:Int){
        var format : CMFormatDescription? = nil
        let status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &audioFormat, 0, nil, 0, nil, nil, &format)
        if status != noErr{
            print(status.description)
        }
        var buffer : CMSampleBuffer? = nil
        var timing = CMSampleTimingInfo.init(duration: CMTimeMake(1, Int32(SampleRate)), presentationTimeStamp: CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000), decodeTimeStamp: kCMTimeInvalid)
        let status1 = CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, format, CMItemCount(numberOfFrames), 1, &timing, 0, nil, &buffer)
        if status1 != noErr{
            print("创建SampleBuffer:" + status1.description)
        }
        if let buffer = buffer{
            let status2 = CMSampleBufferSetDataBufferFromAudioBufferList(buffer, kCFAllocatorDefault, kCFAllocatorDefault, 0, samples)
            if status2 != noErr{
                print("添加SampleBuffer的Data:" + status2.description)
            }
            self.delegate?.onMicAudioUnitRecorderBuffer(buffer: buffer)
        }
    }
}
