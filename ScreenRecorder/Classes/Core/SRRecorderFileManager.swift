//
//  SRRecorderFileManager.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/9/27.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import Foundation

public class SRRecorderFileManager{
    public static let `default` = SRRecorderFileManager()
    
    public var folder : String = {
        let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,FileManager.SearchPathDomainMask.userDomainMask, true)
        return documentPaths[0] + "/SRViewRecorder"
    }()
    
    private init(){
        //创建文件夹
        if !FileManager.default.fileExists(atPath: folder){
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public func directory(with flag:String)->String{
        let str = self.folder + "/" + flag
        if !FileManager.default.fileExists(atPath: str){
            try? FileManager.default.createDirectory(atPath: str, withIntermediateDirectories: true, attributes: nil)
        }
        return str
    }
    
    //根据标记获取所有的视频
    public func files(with flag:String)->[String]{
        let directory = self.directory(with: flag)
        let files = (try? FileManager.default.subpathsOfDirectory(atPath: directory)) ?? []
        let fs = files.sorted(by: { (path1, path2) -> Bool in
            if let filename1 = path1.components(separatedBy: "/").last?.components(separatedBy: ".").first,let filename2 = path2.components(separatedBy: "/").last?.components(separatedBy: ".").first{
                return (Int(filename1) ?? 0) < (Int(filename2) ?? 0)
            }
            return true
        }).map { (str) -> String in
            return directory + "/" + str
        }
        return fs
    }
    
    public func removeAllFiles(with flag:String){
        let d = self.directory(with: flag)
        try? FileManager.default.removeItem(atPath: d)
    }
}
