//
//  AdvancedColorPalletModel.swift
//  spatial-painting-single
//
//  Created by 長尾確 on 2025/07/12.
//

import ARKit
import RealityKit
import SwiftUI
import AVFoundation

struct ColorBall {
    var id: String
    var hue: Int
    var saturation: Int
    var brightness: Int
    var alpha: Int
    var position: SIMD3<Float>
    var isBasic: Bool
}

struct ToolBall {
    var id: String
    var lineWidth: CGFloat
    var position: SIMD3<Float>
    var isEraser: Bool
}

extension Array where Element == ColorBall {
    /// id に合致する ColorBall を返す。見つからなければ nil。
    func get(withID id: String) -> ColorBall? {
        return first { $0.id == id }
    }
    /// id に部分文字列が含まれる ColorBall を返す
    /// - Parameters:
    ///   - substring: 検索する部分文字列
    ///   - caseInsensitive: true の場合は大文字小文字を無視して検索
    ///   - isBasic: true の場合はisBasic=trueのもののみ検索
    /// - Returns: 条件を満たす ColorBall の配列
    func filterByID(containing substring: String,
                    caseInsensitive: Bool = false,
                    isBasic: Bool = false) -> [ColorBall] {
        guard !substring.isEmpty else { return self }
        return filter { ball in
            if isBasic != ball.isBasic { return false }
            if caseInsensitive {
                return ball.id.lowercased().contains(substring.lowercased())
            } else {
                return ball.id.contains(substring)
            }
        }
    }
}

extension Array where Element == ToolBall {
    /// id に合致する ToolBall を返す。見つからなければ nil。
    func get(withID id: String) -> ToolBall? {
        return first { $0.id == id }
    }
    /// id に部分文字列が含まれる ToolBall を返す
    /// - Parameters:
    ///   - substring: 検索する部分文字列
    ///   - caseInsensitive: true の場合は大文字小文字を無視して検索
    /// - Returns: 条件を満たす ToolBall の配列
    func filterByID(containing substring: String,
                    caseInsensitive: Bool = false) -> [ToolBall] {
        guard !substring.isEmpty else { return self }
        return filter { ball in
            if caseInsensitive {
                return ball.id.lowercased().contains(substring.lowercased())
            } else {
                return ball.id.contains(substring)
            }
        }
    }
}

@Observable
@MainActor
class AdvancedColorPalletModel {
    var colorPalletEntity = Entity()
    
    var sceneEntity: Entity? = nil
    
    var player: AVAudioPlayer?
    var isSoundEnabled: Bool = false
    
    var player2: AVAudioPlayer?
    var isSoundEnabled2: Bool = false
    
    let radius: Float = 0.08
    let centerHeight: Float = 0.12
    
    let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.0)
    
    var activeColor = SimpleMaterial.Color.white

    var colorBalls: [ColorBall] = []

    let localOrigin: SIMD3<Float> = SIMD3(0, 0.21, 0)

    var colorDictionary = [String: UIColor]()
    var colorEntityDictionary = [String: Entity]()
    var colorPanelEntityDictionary = [String: Entity]()

    var toolBalls: [ToolBall] = []
    var toolEntityDictionary = [String: Entity]()

    var selectedBasicColorName = ""

    var selectedToolName = ""

    let colorPanelNames: [String] = ["RedColors", "OrangeColors", "YellowColors", "GreenColors", "CyanColors", "BlueColors", "VioletColors", "PinkColors"]

    // Hue マッピング (度数法)
    let hueDegreesMap: [Character: Int] = [
        "r":   0,
        "o":  30,
        "y":  60,
        "g": 120,
        "c": 180,
        "b": 240,
        "v": 270,
        "p": 320
    ]

    // Brightness マッピング (%)
    let brightnessMap: [Int: Int] = [
        1: 100, 2:  90, 3:  75,
        4:  60, 5:  45, 6:  30
    ]

    // Saturation マッピング (%)
    let saturationMap: [Int: Int] = [
        1:  10, 2:  20, 3:  40,
        4:  60, 5:  80, 6: 100
    ]

    //let colors: [SimpleMaterial.Color] = []
    //let colorNames: [String] = []
    
    init() {
        self.sceneEntity = nil
        setupAudioSession()
        let initialColorBalls = [
            ColorBall(id: "red", hue: 0, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(-0.21, 0, 0), isBasic: true),
            ColorBall(id: "orange", hue: 30, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(-0.15, 0, 0), isBasic: true),
            ColorBall(id: "yellow", hue: 60, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(-0.09, 0, 0), isBasic: true),
            ColorBall(id: "green", hue: 120, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(-0.03, 0, 0), isBasic: true),
            ColorBall(id: "cyan", hue: 180, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(0.03, 0, 0), isBasic: true),
            ColorBall(id: "blue", hue: 240, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(0.09, 0, 0), isBasic: true),
            ColorBall(id: "violet", hue: 270, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(0.15, 0, 0), isBasic: true),
            ColorBall(id: "pink", hue: 320, saturation: 100, brightness: 100, alpha: 100, position: SIMD3(0.21, 0, 0), isBasic: true),
            ColorBall(id: "m1", hue: 0, saturation: 0, brightness: 100, alpha: 100, position: SIMD3(0, 0.15, 0), isBasic: false),
            ColorBall(id: "m2", hue: 0, saturation: 0, brightness: 75, alpha: 100, position: SIMD3(0, 0.09, 0), isBasic: false),
            ColorBall(id: "m3", hue: 0, saturation: 0, brightness: 60, alpha: 100, position: SIMD3(0, 0.03, 0), isBasic: false),
            ColorBall(id: "m4", hue: 0, saturation: 0, brightness: 45, alpha: 100, position: SIMD3(0, -0.03, 0), isBasic: false),
            ColorBall(id: "m5", hue: 0, saturation: 0, brightness: 30, alpha: 100, position: SIMD3(0, -0.09, 0), isBasic: false),
            ColorBall(id: "m6", hue: 0, saturation: 0, brightness: 0, alpha: 100, position: SIMD3(0, -0.15, 0), isBasic: false)
        ]
        self.colorBalls = initialColorBalls

        let initialToolBalls = [
            ToolBall(id: "eraser", lineWidth: 0.01, position: SIMD3(0, 0.15, 0), isEraser: true),
            ToolBall(id: "size_1", lineWidth: 0.003, position: SIMD3(0, 0.09, 0), isEraser: false),
            ToolBall(id: "size_2", lineWidth: 0.006, position: SIMD3(0, 0.03, 0), isEraser: false),
            ToolBall(id: "size_3", lineWidth: 0.01, position: SIMD3(0, -0.03, 0), isEraser: false),
            ToolBall(id: "size_4", lineWidth: 0.02, position: SIMD3(0, -0.09, 0), isEraser: false),
            ToolBall(id: "size_5", lineWidth: 0.03, position: SIMD3(0, -0.15, 0), isEraser: false)
        ]
        self.toolBalls = initialToolBalls

        for char in hueDegreesMap.keys {
            for bint in brightnessMap.keys {
                for sint in saturationMap.keys {
                    let id = String(char) + String(bint) + "_" + String(sint)
                    let colorBall = ColorBall(id: id, hue: hueDegreesMap[char]!, saturation: saturationMap[sint]!, brightness: brightnessMap[bint]!, alpha: 100, position: SIMD3(0, 0, 0), isBasic: false)
                    self.colorBalls.append(colorBall)
                }
            }
        }
    }
    
    func setSceneEntity(scene: Entity) {
        sceneEntity = scene
        isSoundEnabled = loadSound()
        isSoundEnabled2 = loadSound2()

        if let entity = sceneEntity?.findEntity(named: "BasicColors") {
            let basicBalls = colorBalls.filter { $0.isBasic }
            for index in 0..<basicBalls.count {
                let cb = basicBalls[index]
                if let colorEntity = entity.findEntity(named: cb.id) {
                    //basicColorEntities.append(colorEntity)
                    let c = UIColor(hue: CGFloat(cb.hue) / 360.0, saturation: CGFloat(cb.saturation) / 100.0, brightness: CGFloat(cb.brightness) / 100.0, alpha: CGFloat(cb.alpha) / 100.0)
                    var activeColor: UIColor!
                    if let p3Color = convertP3(srgbColor: c) {
                        activeColor = p3Color
                    } else {
                        activeColor = c
                    }
                    colorDictionary[cb.id] = activeColor
                    colorEntityDictionary[cb.id] = colorEntity
                }
                //let colorPanelEntity = Entity()
                //colorPanelEntityDictionary[cb.id] = colorPanelEntity
                //colorPalletEntity.addChild(colorPanelEntity)
            }
            print("basic color ball count = \(basicBalls.count)")
        }

        for colorPanelName in colorPanelNames {
            if let entity = sceneEntity?.findEntity(named: colorPanelName) {
                for i in colorBalls.indices {
                    var ball = colorBalls[i]
                    guard ball.id.hasPrefix(colorPanelName.prefix(1).lowercased()), ball.isBasic == false else { continue }
                    if let colorEntity = entity.findEntity(named: ball.id) {
                        let c = UIColor(
                            hue:        CGFloat(ball.hue)        / 360,
                            saturation: CGFloat(ball.saturation) / 100,
                            brightness: CGFloat(ball.brightness) / 100,
                            alpha:      CGFloat(ball.alpha)      / 100
                        )
                        var activeColor: UIColor!
                        if let p3Color = convertP3(srgbColor: c) {
                            activeColor = p3Color
                        } else {
                            activeColor = c
                        }
                        colorDictionary[ball.id] = activeColor
                        colorEntityDictionary[ball.id] = colorEntity

                        ball.position = colorEntity.position
                        colorBalls[i] = ball
                    }
                }
            }
        }

        if let entity = sceneEntity?.findEntity(named: "Grayscale") {
            let grayscaleBalls = colorBalls.filterByID(containing: "m", isBasic: false)
            for index in 0..<grayscaleBalls.count {
                let cb = grayscaleBalls[index]
                if let colorEntity = entity.findEntity(named: cb.id) {
                    //grayscaleColorEntities.append(colorEntity)
                    let c = UIColor(hue: CGFloat(cb.hue) / 360.0, saturation: CGFloat(cb.saturation) / 100.0, brightness: CGFloat(cb.brightness) / 100.0, alpha: CGFloat(cb.alpha) / 100.0)
                    colorDictionary[cb.id] = c
                    colorEntityDictionary[cb.id] = colorEntity
                }
            }
            print("grayscale color ball count = \(grayscaleBalls.count)")
        }

        if let entity = sceneEntity?.findEntity(named: "LineWidth") {
            for index in 0..<toolBalls.count {
                let tb = toolBalls[index]
                if let toolEntity = entity.findEntity(named: tb.id) {
                    toolEntityDictionary[tb.id] = toolEntity
                }
            }
            print("tool ball count = \(self.toolBalls.count)")
        }
    }
    
    func convertP3(srgbColor: UIColor) -> UIColor! {
        //print("original color space \(srgbColor.cgColor.components)")
        guard let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
            print("cannot create p3 color space")
            return nil
        }
        guard let converted = srgbColor.cgColor.converted(to: p3ColorSpace, intent: .defaultIntent, options: nil) else {
            print("cannot convert to p3 color space")
            return nil
        }
        //print("converted to p3 color space \(converted.components)")
        return UIColor(cgColor: converted)
    }
    
    func setActiveColor(color: SimpleMaterial.Color) {
        activeColor = color
    }
    
    func colorNames() -> [String] {
        return Array(colorDictionary.keys)
    }

    func toolNames() -> [String] {
        return toolEntityDictionary.keys.filter { $0 != "eraser" }
    }

    func updatePosition(position: SIMD3<Float>, wristPosition: SIMD3<Float>) {
        // 1) 手から手首への水平ベクトル
        let toWrist = normalize(simd_make_float3(
            wristPosition.x - position.x,
            0,
            wristPosition.z - position.z
        ))
        
        // 2) 符号付きヨー角 (rad)：右手系で y 軸回り
        let dx = toWrist.x
        let dz = toWrist.z
        let yaw = atan2(dx, dz)

        var grayscalePosition: SIMD3<Float> = localOrigin
        var toolPosition: SIMD3<Float> = localOrigin

        let basicBalls = colorBalls.filter { $0.isBasic }
        for (index, colorBall) in zip(basicBalls.indices, basicBalls) {
            let entity: Entity = colorEntityDictionary[colorBall.id]!

            // 回転後オフセット
            let xRot: Float = colorBall.position.x * cos(yaw) - colorBall.position.z * sin(yaw)
            let zRot: Float = colorBall.position.x * sin(yaw) + colorBall.position.z * cos(yaw)
            let yPos: Float = colorBall.position.y + centerHeight

            let rotatedOffset = SIMD3<Float>(xRot, yPos, zRot)

            let newPosition: SIMD3<Float> = position + rotatedOffset
            entity.setPosition(newPosition, relativeTo: nil)

            /*
            entity.setScale(SIMD3<Float>(repeating: 0.01), relativeTo: nil)
            if colorBall.isSelected {
                entity.setScale(SIMD3<Float>(repeating: 0.013), relativeTo: nil)
            }
            */
            
            if index == 0 {
                grayscalePosition += newPosition
            } else if index == basicBalls.count - 1 {
                toolPosition += newPosition
            }
        }

        let grayscaleBalls = colorBalls.filter { !$0.isBasic }
        for colorBall in grayscaleBalls {
            let entity: Entity = colorEntityDictionary[colorBall.id]!
            entity.setPosition(grayscalePosition + colorBall.position, relativeTo: nil)
        }

        for toolBall in toolBalls {
            let entity: Entity = toolEntityDictionary[toolBall.id]!
            entity.setPosition(toolPosition + toolBall.position, relativeTo: nil)
        }
        /*
        for (index,color) in zip(colors.indices, colors) {
            let radians: Float = Float.pi / 180.0 * 360.0 / Float(colors.count) * Float(index)
            var ballPosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 0.0)
            
            let rotatedOffset = SIMD3<Float>(
                radius * sin(radians) * cos(yaw) - 0 * sin(yaw),
                radius * cos(radians) + centerHeight,
                radius * sin(radians) * sin(yaw) + 0 * cos(yaw)
            )
            
            if index == 0 || index == Int(colors.count / 2) {
                ballPosition = position + SIMD3<Float>(radius * sin(radians), radius * cos(radians) + centerHeight, 0.0)
            } else {
                //ballPosition = position + SIMD3<Float>(radius * sin(radians) * cos(angle), radius * cos(radians) + centerHeight, radius * sin(radians) * sin(angle))
                ballPosition = position + rotatedOffset
            }
            
            //colorPalletEntity.findEntity(named: color.accessibilityName)?.setPosition(ballPosition, relativeTo: nil)
            let words = color.accessibilityName.split(separator: " ")
            if let name = words.last, let entity = colorPalletEntity.findEntity(named: String(name)) {
                entity.setPosition(ballPosition, relativeTo: nil)
            }
        }
        
        if let entity = colorPalletEntity.findEntity(named: "clear") {
            let spherePosition: SIMD3<Float> = position + SIMD3<Float>(0, centerHeight, 0)
            entity.setPosition(spherePosition, relativeTo: nil)
        }
        */
    }
    
    func updatePosition2(position: SIMD3<Float>, unitVector: SIMD3<Float>) {
        var grayscalePosition: SIMD3<Float> = localOrigin
        var toolPosition: SIMD3<Float> = localOrigin
        let colorPosition: SIMD3<Float> = localOrigin + position

        let basicBalls = colorBalls.filter { $0.isBasic }
        for (index, colorBall) in zip(basicBalls.indices, basicBalls) {
            let entity: Entity = colorEntityDictionary[colorBall.id]!

            // オフセット
            let xOff: Float = 0
            let zOff: Float = 0
            let yOff: Float = centerHeight

            let offset = SIMD3<Float>(xOff, yOff, zOff)

            let newPosition: SIMD3<Float> = calculateExtendedPoint(point: position + offset, vector: unitVector, distance: colorBall.position.x)
            entity.setPosition(newPosition, relativeTo: nil)

            if index == 0 {
                grayscalePosition += newPosition
            } else if index == basicBalls.count - 1 {
                toolPosition += newPosition
            }
            
            if colorBall.id == selectedBasicColorName {
                //print("Selected color ball = \(colorBall.id)")
                let subColorBalls = colorBalls.filterByID(containing: String(colorBall.id.prefix(1)), isBasic: false)
                for cb in subColorBalls {
                    if let entity2: Entity = colorEntityDictionary[cb.id] {
                        let newPosition2: SIMD3<Float> = calculateExtendedPoint(point: colorPosition + SIMD3<Float>(0, cb.position.y + yOff, 0), vector: unitVector, distance: cb.position.x)
                        entity2.setPosition(newPosition2, relativeTo: nil)
                        //print("Sub color ball \(cb.id) local position \(cb.position) new position \(newPosition2)")
                    }
                }
                //colorPalletEntity.addChild(colorPanelEntityDictionary[colorBall.id]!)
            }
        }

        let grayscaleBalls = colorBalls.filterByID(containing: "m", isBasic: false)
        for colorBall in grayscaleBalls {
            if let entity: Entity = colorEntityDictionary[colorBall.id] {
                entity.setPosition(grayscalePosition + colorBall.position, relativeTo: nil)
            }
        }

        for toolBall in toolBalls {
            if let entity: Entity = toolEntityDictionary[toolBall.id] {
                entity.setPosition(toolPosition + toolBall.position, relativeTo: nil)
            }
        }
    }

    // 点から単位ベクトル方向にある、その点から一定距離分離れた位置の点を計算する関数
    func calculateExtendedPoint(point: SIMD3<Float>, vector: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
        // 単位ベクトルにスカラー量（距離）を掛けて延長方向のベクトルを計算
        let extensionVector = SIMD3<Float>(x: vector.x * distance, y: vector.y * distance, z: vector.z * distance)
        
        // 点に延長ベクトルを加えて、新しい点の座標を計算
        let extendedPoint = SIMD3<Float>(x: point.x + extensionVector.x, y: point.y + extensionVector.y, z: point.z + extensionVector.z)
        
        return extendedPoint
    }

    func initEntity() {
        for colorBall in colorBalls {
            if let entity: Entity = colorEntityDictionary[colorBall.id] {
                entity.setPosition(colorBall.position, relativeTo: nil)
                colorPalletEntity.addChild(entity)
            }
        }
        for toolBall in toolBalls {
            if let entity: Entity = toolEntityDictionary[toolBall.id] {
                entity.setPosition(toolBall.position, relativeTo: nil)
                colorPalletEntity.addChild(entity)
            }
        }
        /*
        for (index,color) in zip(colors.indices, colors) {
            let deg = 360.0 / Float(colors.count) * Float(index)
            let radians: Float = Float.pi / 180.0 * deg
            //print("💥 Color accessibilityName \(index): \(color.accessibilityName)")
            createColorBall(color: color, radians: radians, radius: radius, parentPosition: colorPalletEntity.position)
        }
        if let entity = sceneEntity?.findEntity(named: "clear") {
            let position: SIMD3<Float> = SIMD3(0, centerHeight, 0)
            entity.setPosition(position, relativeTo: nil)
            colorPalletEntity.addChild(entity)
        }
        */
    }
    
    func createColorBall(color: SimpleMaterial.Color, radians: Float, radius: Float, parentPosition: SIMD3<Float>) {
        // added by nagao 3/22
        let words = color.accessibilityName.split(separator: " ")
        if let name = words.last, let entity = sceneEntity?.findEntity(named: String(name)) {
            let position: SIMD3<Float> = SIMD3(radius * sin(radians), radius * cos(radians), 0)
            //print("💥 Created color: \(color.accessibilityName), position: \(position)")
            entity.setPosition(position, relativeTo: nil)
            colorPalletEntity.addChild(entity)
        }
    }
    
    func colorPalletEntityEnabled() {
        if isSoundEnabled && !colorPalletEntity.isEnabled {
            player?.play()
        }
        
        colorPalletEntity.isEnabled = true
    }
    
    func colorPalletEntityDisable() {
        if (colorPalletEntity.isEnabled) {
            Task {
                DispatchQueue.main.async {
                    self.colorPalletEntity.isEnabled = false
                }
            }
        }
    }
    
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッションの設定に失敗しました: \(error)")
        }
    }
    
    func loadSound() -> Bool {
        guard let soundURL = Bundle.main.url(forResource: "showPallet", withExtension: "mp3") else { return false }
        
        do {
            player = try AVAudioPlayer(contentsOf: soundURL)
            return true
        } catch {
            print("音声ファイルの読み込みに失敗しました")
            return false
        }
    }
    
    func loadSound2() -> Bool {
        guard let soundURL = Bundle.main.url(forResource: "shutter", withExtension: "mp3") else { return false }
        
        do {
            player2 = try AVAudioPlayer(contentsOf: soundURL)
            return true
        } catch {
            print("音声ファイルの読み込みに失敗しました")
            return false
        }
    }
    
    func playShutterSound() {
        if isSoundEnabled2 {
            player2?.play()
        }
    }
}
