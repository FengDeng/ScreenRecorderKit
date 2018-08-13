//
//  ViewController.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/26.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import UIKit
import AVKit
import Photos
import GLKit
import OpenGLES



class ViewController: UIViewController,SRViewRecorderDelegate {
    func onViewRecorderPaused() {
        print("结束录制")
    }
    
    func onViewRecorderStarted() {
        print("开始录制")
    }
    
    func onViewRecorderPartsChanged(assets: [AVURLAsset]) {
        print("分片发生了变化：\(assets.count)")
    }
    
    func onViewRecorderProgressing(seconds: CGFloat) {
        DispatchQueue.main.async {
            self.label.text = String.init(format: "%.2f", seconds)
        }
    }
    
    func onViewRecorderError(error: Error) {
        
    }
    

    
    let label = UILabel()
    var recorder : SRViewRecorder!
    var p : PPTPaint!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.recorder = SRViewRecorder.init(view: self.view!, folderName: "1234")
        // Do any additional setup after loading the view, typically from a nib.
        recorder.delegate = self

        
        label.textColor = UIColor.black
        self.view.addSubview(label)
        label.frame = CGRect.init(x: 0, y: 50, width: 300, height: 50)
        
        let btn1 = UIButton()
        btn1.backgroundColor = UIColor.blue
        btn1.setTitle("开始", for: UIControlState.normal)
        btn1.frame = CGRect.init(x: 0, y: 100, width: 100, height: 100)
        btn1.addTarget(self, action: #selector(start), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn1)
        
        let btn2 = UIButton()
        btn2.backgroundColor = UIColor.green
        btn2.setTitle("结束", for: UIControlState.normal)
        btn2.frame = CGRect.init(x: 0, y: 200, width: 100, height: 100)
        btn2.addTarget(self, action: #selector(end), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn2)
        
        let btn3 = UIButton()
        btn3.backgroundColor = UIColor.yellow
        btn3.setTitle("崩溃", for: UIControlState.normal)
        btn3.frame = CGRect.init(x: 0, y: 300, width: 100, height: 100)
        btn3.addTarget(self, action: #selector(crash), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn3)
        
        let btn4 = UIButton()
        btn4.backgroundColor = UIColor.yellow
        btn4.setTitle("播放", for: UIControlState.normal)
        btn4.frame = CGRect.init(x: 100, y: 100, width: 100, height: 100)
        btn4.addTarget(self, action: #selector(play), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn4)
        
        let btn5 = UIButton()
        btn5.backgroundColor = UIColor.yellow
        btn5.setTitle("删除所有", for: UIControlState.normal)
        btn5.frame = CGRect.init(x: 100, y: 200, width: 100, height: 100)
        btn5.addTarget(self, action: #selector(deleteAll), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn5)
        
        let btn6 = UIButton()
        btn6.backgroundColor = UIColor.yellow
        btn6.setTitle("删除last", for: UIControlState.normal)
        btn6.frame = CGRect.init(x: 100, y: 300, width: 100, height: 100)
        btn6.addTarget(self, action: #selector(deleteLast), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn6)
        
        let btn7 = UIButton()
        btn7.backgroundColor = UIColor.red
        btn7.setTitle("降噪开", for: UIControlState.normal)
        btn7.frame = CGRect.init(x: 200, y: 100, width: 100, height: 100)
        btn7.addTarget(self, action: #selector(echo), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn7)
        
        let btn8 = UIButton()
        btn8.backgroundColor = UIColor.red
        btn8.setTitle("保存到相册", for: UIControlState.normal)
        btn8.frame = CGRect.init(x: 200, y: 200, width: 100, height: 100)
        btn8.addTarget(self, action: #selector(save), for: UIControlEvents.touchUpInside)
        self.view.addSubview(btn8)
        
         p = PPTPaint.init(frame: CGRect.init(x: 200, y: 0, width: 300, height: 500))
        self.view.addSubview(p)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func start(){
        recorder.start()
    }
    
    @objc func end(){
        recorder.pause()
    }
    
    @objc func crash(){
//        let a = [1,2]
//        let b = a[3]
        let a : NSArray = NSArray.init(objects: "1","2")
        let c = a[4]
    }
    
    var player : AVPlayer? = nil
    @objc func play(){
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch  {
            print(error)
        }
        let composition = recorder.composition
        let item = AVPlayerItem.init(asset: composition)
        self.player = AVPlayer.init(playerItem: item)
        player?.play()
        let layer = AVPlayerLayer.init(player: player)
        self.view.layer.addSublayer(layer)
        self.player?.volume = 2.0
        layer.frame = CGRect.init(x: 0, y: 400, width: UIScreen.main.bounds.width, height: 300)
    }
    
    @objc func deleteAll(){
        recorder.deleteAll()
    }
    
    @objc func deleteLast(){
        recorder.deleteLast()
    }
    
    @objc func echo(btn:UIButton){
        
    }
    @objc func save(){
//        recorder.generateDelegate = self
//        recorder.generate(outFilePath: NSTemporaryDirectory() + "123.mp4")
    }
}

extension ViewController{
    
}

