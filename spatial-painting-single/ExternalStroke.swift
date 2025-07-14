//
//  File.swift
//  spatial-painting-single
//
//  Created by blueken on 2025/06/24.
//

import Foundation
import RealityKit
import CoreGraphics

extension [ExternalStroke] {
    init(strokes: [Stroke], initPoint: SIMD3<Float> = .zero) {
        self = strokes.map {
            ExternalStroke(stroke: $0, initPoint: initPoint)
        }
    }
    
    func strokes(initPoint: SIMD3<Float> = .zero) -> [Stroke] {
        return self.map {
            $0.stroke(initPoint: initPoint)
        }
    }
}

struct ExternalStroke: Codable {
    var points: [SIMD3<Float>] = []
    var color: CGColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    var maxRadius: Float = 1E-2
    
    enum CodingKeys: String, CodingKey {
        case points
        case color
        case maxRadius
    }
    
    public init(stroke: Stroke, initPoint: SIMD3<Float> = .zero) {
        // initPointからの相対位置に変換
        self.points = stroke.points.map { $0 - initPoint }
        self.color = stroke.activeColor.cgColor
        self.maxRadius = stroke.originalMaxRadius
    }
    
    public init(points: [SIMD3<Float>] = [], color: SimpleMaterial.Color = .white, initPoint: SIMD3<Float> = .zero, maxRadius: Float = 1E-2) {
        // initPointからの相対位置に変換
        self.points = points.map { $0 - initPoint }
        self.color = color.cgColor
        self.maxRadius = maxRadius
    }
    
    public init(points: [SIMD3<Float>] = [], color: CGColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), initPoint: SIMD3<Float> = .zero, maxRadius: Float = 1E-2) {
        self.points = points.map { $0 - initPoint }
        self.color = color
        self.maxRadius = maxRadius
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pointArrays = try container.decode([[Float]].self, forKey: .points)
        self.points = pointArrays.map { SIMD3<Float>($0) }
        let colorArray = try container.decode([Float].self, forKey: .color)
        self.color = CGColor(red: CGFloat(colorArray[0]), green: CGFloat(colorArray[1]), blue: CGFloat(colorArray[2]), alpha: CGFloat(colorArray[3]))
        self.maxRadius = try container.decode(Float.self, forKey: .maxRadius)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let pointArrays = points.map { [$0.x, $0.y, $0.z] }
        try container.encode(pointArrays, forKey: .points)
        let colorArray: [Float]
        if let components = color.components, components.count >= 4 {
            colorArray = [Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3])]
        } else {
            colorArray = [1, 1, 1, 1]
        }
        try container.encode(colorArray, forKey: .color)
        try container.encode(maxRadius, forKey: .maxRadius)
    }
    
    func stroke(initPoint: SIMD3<Float> = .zero) -> Stroke {
        let tmpStroke = Stroke(uuid: UUID(), originalMaxRadius: self.maxRadius)
        tmpStroke.points = self.points.map { $0 + initPoint }
        tmpStroke.setActiveColor(color: SimpleMaterial.Color(cgColor: self.color))
        tmpStroke.maxRadius = self.maxRadius
        return tmpStroke
    }
}

