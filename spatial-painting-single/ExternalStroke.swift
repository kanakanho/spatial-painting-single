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
    var color: SimpleMaterial.Color = .red
    var maxRadius: Float = 1E-2
    
    enum CodingKeys: String, CodingKey {
        case points
        case color
        case maxRadius
    }
    
    public init(stroke: Stroke, initPoint: SIMD3<Float> = .zero) {
        // initPointからの相対位置に変換
        self.points = stroke.points.map { $0 - initPoint }
        self.color = stroke.activeColor
        self.maxRadius = stroke.maxRadius //修正 by nagao 2025/7/15
    }
    
    public init(points: [SIMD3<Float>] = [], color: SimpleMaterial.Color = .white, initPoint: SIMD3<Float> = .zero, maxRadius: Float = 1E-2) {
        // initPointからの相対位置に変換
        self.points = points.map { $0 - initPoint }
        self.color = color
        self.maxRadius = maxRadius
    }
    
    public init(points: [SIMD3<Float>] = [], color: CGColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), initPoint: SIMD3<Float> = .zero, maxRadius: Float = 1E-2) {
        self.points = points.map { $0 - initPoint }
        self.color = .init(cgColor: color)
        self.maxRadius = maxRadius
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pointArrays = try container.decode([[Float]].self, forKey: .points)
        self.points = pointArrays.map { SIMD3<Float>($0) }

        // maxRadius の有無を確認
        let hasMaxRadius = container.contains(.maxRadius)
        let colorArray = try container.decode([Float].self, forKey: .color)
        guard colorArray.count == 4 else {
            throw DecodingError.dataCorruptedError(forKey: .color, in: container, debugDescription: "Color array must have 4 elements")
        }

        if hasMaxRadius {
            // HSVA（Hue, Saturation, Value, Alpha）
            self.color = .init(hue: CGFloat(colorArray[0]), saturation: CGFloat(colorArray[1]), brightness: CGFloat(colorArray[2]), alpha: CGFloat(colorArray[3]))
        } else {
            // RGBA（Red, Green, Blue, Alpha）
            self.color = .init(red: CGFloat(colorArray[0]), green: CGFloat(colorArray[1]), blue: CGFloat(colorArray[2]), alpha: CGFloat(colorArray[3]))
        }

        self.maxRadius = try container.decodeIfPresent(Float.self, forKey: .maxRadius) ?? 1E-2
    }

    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let pointArrays = points.map { [$0.x, $0.y, $0.z] }
        try container.encode(pointArrays, forKey: .points)
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        try container.encode([hue, saturation, brightness, alpha], forKey: .color)
        try container.encode(maxRadius, forKey: .maxRadius)
    }
    
    func stroke(initPoint: SIMD3<Float> = .zero) -> Stroke {
        let tmpStroke = Stroke(uuid: UUID(), originalMaxRadius: self.maxRadius)
        tmpStroke.points = self.points.map { $0 + initPoint }
        tmpStroke.setActiveColor(color: self.color)
        tmpStroke.maxRadius = self.maxRadius
        return tmpStroke
    }
}

