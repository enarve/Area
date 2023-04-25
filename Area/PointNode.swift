//
//  PointNode.swift
//  Area
//
//  Created by sinezeleuny on 19.02.2022.
//

import UIKit
import SceneKit

class PointNode: SCNNode {
    var radius = 0.04
    
    var polygonTangent: Double = 0
    var index = 0
    
    override init() {
        super.init()
        self.geometry = SCNSphere(radius: radius)
    }
    
    init(radius: CGFloat) {
        super.init()
        self.geometry = SCNSphere(radius: radius)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? PointNode {
            return super.isEqual(object) && self.index == object.index
        }
        return super.isEqual(object)
    }
}
