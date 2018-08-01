//
//  PPTPaint.swift
//  UGCCreate_Example
//
//  Created by 邓锋 on 2018/6/30.
//  Copyright © 2018年 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class PPTPaint: UIView {

    fileprivate var lines = [CAShapeLayer]()
    var lineColor: UIColor = UIColor.black
    var lineWidth: Float = 2
    fileprivate var bezierPath: UIBezierPath?
    fileprivate var shapeLayer: CAShapeLayer?
    fileprivate var previousPoint : CGPoint? = nil
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // 清除所有
    func clear() {
        if lines.count < 1 {
            return
        }
        for layer in lines {
            layer.removeFromSuperlayer()
        }
        lines.removeAll()
    }
    
}

//MARK: - 代理
extension PPTPaint {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let startP = pointWithTouchs(touches: touches)
        if event?.allTouches?.count == 1 {
    
            self.previousPoint = startP
            let path = paintPath(lineWidth: CGFloat(self.lineWidth), startP: startP)
            self.bezierPath = path
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.backgroundColor = UIColor.clear.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = kCALineCapRound
            layer.lineJoin = kCALineJoinRound
            layer.strokeColor = self.lineColor.cgColor
            layer.lineWidth = path.lineWidth
            self.layer.addSublayer(layer)
            self.shapeLayer = layer
            lines.append(layer)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let moveP = pointWithTouchs(touches: touches)
        if event?.allTouches?.count ?? 0 > 1 {
            self.superview?.touchesMoved(touches, with: event)
        } else if event?.allTouches?.count ?? 0 == 1 {
            if let pre = self.previousPoint{
                let midP = CGPoint.init(x: (pre.x + moveP.x) / 2, y: (pre.y + moveP.y) / 2 )
                bezierPath?.addQuadCurve(to: midP, controlPoint: pre)
            }else{
                bezierPath?.addLine(to: moveP)
            }
            shapeLayer?.path = bezierPath?.cgPath
        }
        self.previousPoint = moveP
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.count ?? 0 > 1 {
            self.superview?.touchesEnded(touches, with: event)
        }
        if let layer = self.shapeLayer{
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                layer.removeFromSuperlayer()
            }
        }
        
    }
}

// 绘图相关私有方法
extension PPTPaint {
    
    fileprivate func pointWithTouchs(touches: Set<UITouch>) -> CGPoint {
        guard let touch = touches.first else {return CGPoint(x:0, y:0) }
        return touch.location(in: self)
    }
    
    fileprivate func paintPath(lineWidth: CGFloat, startP: CGPoint) -> UIBezierPath {
        let path = UIBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: startP)
        return path
    }
    
}
