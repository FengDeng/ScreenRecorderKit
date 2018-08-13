//
//  SRViewCapture.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/9.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation
import UIKit
import AVKit

protocol SRViewCaptureDelegate : class {
    func onViewCapturePixelBuffer(buffer:CVPixelBuffer,time:CMTime)
}

///截屏 并生产CVPixelBuffer
class SRViewCapture {
    
    private lazy var displayLink : CADisplayLink = {
        let link = CADisplayLink.init(target: self, selector: #selector(handleDisplayLink))
        link.isPaused = true
        link.add(to: .main, forMode: .commonModes)
        return link
    }()
    
    private let queue = OperationQueue.init()

    /* Defines how many display frames must pass between each time the
     * display link fires. Default value is two, which means the display
     * link will fire for every two display frame.  */
    public var frameInterval = 2{
        didSet{
            self.displayLink.frameInterval = frameInterval
        }
    }
    
    
    init(view:UIView) {
        self.view = view
        self.queue.maxConcurrentOperationCount = 1
    }
    
    /// 当前录制的view
    public weak var view : UIView? = UIApplication.shared.keyWindow
    public weak var delegate : SRViewCaptureDelegate?
    @objc private func handleDisplayLink(){
        DispatchQueue.main.async {[weak self] in
            guard let `self` = self,let layer = self.view?.layer else{return}
            self.queue.addOperation {[weak self] in
                guard let `self` = self else{return}
                if let buffer = layer.pixelBuffer(){
                    let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000)
                    self.delegate?.onViewCapturePixelBuffer(buffer: buffer, time: now)
                }
            }
        }
    }
}

extension SRViewCapture{
    func start(){
        self.displayLink.isPaused = false
    }
    func pause(){
        self.displayLink.isPaused = true
        self.queue.cancelAllOperations()
    }
}
