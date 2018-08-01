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
    
    let queue = DispatchQueue.init(label: "com.RPViewVideoRecorder.buffer.queue")
    
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
        if let layer = self.view?.layer{
            self.queue.async {[weak self] in
                guard let `self` = self else{return}
                if let cgImage = layer.image()?.cgImage{
                    if let buffer = ImageProcessor.pixelBuffer(forImage: cgImage){
                        self.delegate?.onViewVideoRecorderBuffer(buffer: buffer)
                    }
                }
            }
        }
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


//extension CVPixelBuffer{
//    func sampleBuffer()->CMSampleBuffer?{
//        var newSampleBuffer: CMSampleBuffer? = nil
//        var timimgInfo: CMSampleTimingInfo = kCMTimingInfoInvalid
//        var videoInfo: CMVideoFormatDescription? = nil
//        CMVideoFormatDescriptionCreateForImageBuffer(nil, self, &videoInfo)
//        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, self, true, nil, nil, videoInfo!, &timimgInfo, &newSampleBuffer)
//        return newSampleBuffer
//    }
//}

struct ImageProcessor {
    static func pixelBuffer (forImage image:CGImage) -> CVPixelBuffer? {
        let frameSize = CGSize(width: image.width, height: image.height)
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            return nil
            
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
        
    }
    
}
