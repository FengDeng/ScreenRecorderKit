//
//  SRViewRecorderException.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/8/13.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation

//异常的处理，捕获到异常的时候暂停录制

class WeakBox<E : AnyObject>{
    weak var element : E?
    init(element:E?) {
        self.element = element
    }
}

class SRViewRecorderException{
    
    public static let `default` = SRViewRecorderException()
    fileprivate var recorders = [WeakBox<SRViewRecorder>]()
    private init() {
        //没必要移除了 这是个单例
        //应用退到后台
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        //录音被打断
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        
        NSSetUncaughtExceptionHandler { (e) in
            SRViewRecorderException.default.save()
        }
    }
    
    @objc private func save(){
        for recorder in self.recorders{
            recorder.element?.pause()
        }
    }
    
    func append(recorder:SRViewRecorder){
        self.recorders.append(WeakBox<SRViewRecorder>.init(element: recorder))
    }

}
