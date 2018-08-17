//
//  ImageProcessor.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/9.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import AVKit
import CoreGraphics
extension CALayer{
    func pixelBuffer()->CVPixelBuffer?{
        let width = Int(self.bounds.width)
        let height = Int(self.bounds.height)
        //分配pixelBuffer内存
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }
        //锁定地址
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        }
        //创建上下文  进行渲染
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        //context?.scaleBy(x: UIScreen.main.scale, y: UIScreen.main.scale)
        let flip = CGAffineTransform.init(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height))
        context?.concatenate(flip)
        self.render(in: context!)
        return pixelBuffer
    }
}

extension UIView{
    func cgImage()->CGImage?{
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, UIScreen.main.scale)
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.cgImage
    }
    
    func pixelBuffer()->CVPixelBuffer?{
        let width = Int(self.bounds.width)
        let height = Int(self.bounds.height)
        //分配pixelBuffer内存
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }
        //锁定地址
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        }
        //创建上下文  进行渲染
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        //context?.scaleBy(x: UIScreen.main.scale, y: UIScreen.main.scale)
        let flip = CGAffineTransform.init(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height))
        context?.concatenate(flip)
        UIGraphicsPushContext(context!)
        //self.render(in: context!)
        self.drawHierarchy(in: self.frame, afterScreenUpdates: false)
        UIGraphicsPopContext()
        return pixelBuffer
    }
}




extension CGImage{
    func pixelBuffer()->CVPixelBuffer?{
        let frameSize = CGSize(width: self.width, height: self.height)
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
        
        
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
