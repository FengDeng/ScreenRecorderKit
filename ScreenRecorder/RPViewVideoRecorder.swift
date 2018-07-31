//
//  RPViewVideoRecorder.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit


//从一个view提供视频流
protocol RPViewVideoRecorderDelegate : class {
    func onViewVideoRecorderBuffer(buffer:CVPixelBuffer)
}
class RPViewVideoRecorder {
    
    var displayLink : CADisplayLink?
    var frameInterval = 3 //三帧回调一次
    
    let queue = DispatchQueue.init(label: "com.RPViewVideoRecorder.buffer.queue", qos: DispatchQoS.userInteractive)
    
    weak var view : UIView?
    weak var delegate : RPViewVideoRecorderDelegate?

    func startCapture(view:UIView,delegate:RPViewVideoRecorderDelegate?){
        self.view = view
        self.delegate = delegate
        //初始化定时器
        self.displayLink = CADisplayLink.init(target: self, selector: #selector(handleDisplayLink))
        self.displayLink?.frameInterval = self.frameInterval
        self.displayLink?.add(to: .main, forMode: .commonModes)
    }
    
    func stopCapture(){
        self.displayLink?.remove(from: .main, forMode: .commonModes)
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    @objc private func handleDisplayLink(){
        //同步获取view的截图
        self.queue.sync {[weak self] in
            guard let `self` = self else{return}
            if let buffer = self.view?.layer.image()?.pixelBuffer(){
                 self.delegate?.onViewVideoRecorderBuffer(buffer: buffer)
            }
        }
    }
}

extension CVPixelBuffer{
    func sampleBuffer()->CMSampleBuffer?{
        var newSampleBuffer: CMSampleBuffer? = nil
        var timimgInfo: CMSampleTimingInfo = kCMTimingInfoInvalid
        var videoInfo: CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(nil, self, &videoInfo)
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, self, true, nil, nil, videoInfo!, &timimgInfo, &newSampleBuffer)
        return newSampleBuffer
    }
}

//转化Buffer
extension CALayer{
    func image()->UIImage?{
        let size = self.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, true, UIScreen.main.scale)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else{
            UIGraphicsEndImageContext()
            return nil
        }
        self.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        return image
    }
}

extension UIImage {
    public func pixelBuffer() -> CVPixelBuffer? {
        return pixelBuffer(width: Int(size.width * UIScreen.main.scale), height: Int(size.height * UIScreen.main.scale))
    }
    
    /**
     Resizes the image to width x height and converts it to an RGB CVPixelBuffer.
     */
    public func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        return pixelBuffer(width: width, height: height,
                           pixelFormatType: kCVPixelFormatType_32ARGB,
                           colorSpace: CGColorSpaceCreateDeviceRGB(),
                           alphaInfo: .noneSkipFirst)
    }
    
    /**
     Resizes the image to width x height and converts it to a grayscale CVPixelBuffer.
     */
    public func pixelBufferGray(width: Int, height: Int) -> CVPixelBuffer? {
        return pixelBuffer(width: width, height: height,
                           pixelFormatType: kCVPixelFormatType_OneComponent8,
                           colorSpace: CGColorSpaceCreateDeviceGray(),
                           alphaInfo: .none)
    }
    
    func pixelBuffer(width: Int, height: Int, pixelFormatType: OSType,
                     colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {
        var maybePixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormatType,
                                         attrs as CFDictionary,
                                         &maybePixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: colorSpace,
                                      bitmapInfo: alphaInfo.rawValue)
            else {
                return nil
        }
        context.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}
