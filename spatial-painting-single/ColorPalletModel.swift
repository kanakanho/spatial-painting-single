//
//  ColorPallet.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/20.
//

import ARKit
import RealityKit
import SwiftUI
import AVFoundation

@Observable
@MainActor
class ColorPalletModel {
    var colorPalletEntity = Entity()
    
    var sceneEntity: Entity? = nil
    
    var player: AVAudioPlayer?
    var isSoundEnabled: Bool = false

    let radius: Float = 0.08
    let centerHeight: Float = 0.12
    
    let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.0)
    
    var activeColor = SimpleMaterial.Color.white
    
    let colors: [SimpleMaterial.Color] = [
        .white,
        .black,
        .brown,
        .red,
        .orange,
        .yellow,
        .green,
        .cyan,
        .blue,
        .purple
    ]
    
    // added by nagao 3/22
    let colorNames: [String] = [
        "white",
        "black",
        "brown",
        "red",
        "orange",
        "yellow",
        "green",
        "cyan",
        "blue",
        "magenta"
    ]
    
    // added by nagao 3/28
    init() {
        self.sceneEntity = nil
        setupAudioSession()
    }

    // added by nagao 3/22
    func setSceneEntity(scene: Entity) {
        sceneEntity = scene
        isSoundEnabled = loadSound()
    }
    
    // modified by nagao 3/22
    func setActiveColor(color: SimpleMaterial.Color) {
        activeColor = color
        // 該当の色を小さくする
        /*
         for child in colorPalletEntity.children {
         if child.name == color.accessibilityName {
         child.setScale(SIMD3<Float>(0.9,0.9,0.9), relativeTo: nil)
         } else {
         child.setScale(SIMD3<Float>(1.0,1.0,1.0), relativeTo: nil)
         }
         }
         */
    }
    
    // modified by nagao 2025/6/16
    func updatePosition(position: SIMD3<Float>, headPosition: SIMD3<Float>) {
        /*
        // 頭と手を結ぶベクトル
        let vector1 = simd_float3(x: position.x - headPosition.x, y: 0, z: position.z - headPosition.z)
        let radiansS: Float = Float.pi / 180.0 * 360.0 / Float(colors.count) * 1.0
        let radiansL: Float = Float.pi / 180.0 * 360.0 / Float(colors.count) * Float(colors.count - 1)
        let ballPositionS: SIMD3<Float> = SIMD3<Float>(radius * sin(radiansS), radius * cos(radiansS) + centerHeight, 0.0)
        let ballPositionL: SIMD3<Float> = SIMD3<Float>(radius * sin(radiansL), radius * cos(radiansL) + centerHeight, 0.0)
        // SecondballとLastballを結ぶベクトル
        let vector2 = simd_float3(x: ballPositionS.x - ballPositionL.x, y: 0, z: ballPositionS.z - ballPositionL.z)
        // 内積を使って角度の大きさを計算
        let dotProduct = simd_dot(normalize(vector1), normalize(vector2))
        let clampedDot = max(-1.0, min(1.0, dotProduct))  // [-1, 1] に制限
        let angle = acos(clampedDot) - Float.pi / 2.0 // 角度（ラジアン）
        */
        // 1) 手から頭への水平ベクトル
        let toHead = normalize(simd_make_float3(
            headPosition.x - position.x,
            0,
            headPosition.z - position.z
        ))

        // 2) ワールド前方向ベクトル (RealityKit ではカメラ前方が -z)
        let worldForward = normalize(simd_float3(0, 0, -1))

        // 3) 符号付きヨー角 (rad)：右手系で y 軸回り
        let yaw = atan2(
            simd_dot(toHead, simd_float3(1,0,0)),      // x 成分
            simd_dot(toHead, worldForward)             // z 成分
        )

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
    }
    
    // modified by nagao 3/22
    func initEntity() {
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
    }
    
    // modified by nagao 3/22
    func createColorBall(color: SimpleMaterial.Color, radians: Float, radius: Float, parentPosition: SIMD3<Float>) {
        /*
         let ball = ModelEntity(
         mesh: .generateSphere(radius: 0.02),
         materials: [SimpleMaterial(color: color, isMetallic: true)],
         collisionShape: .generateSphere(radius: 0.05),
         mass: 0.0
         )
         ball.name = color.accessibilityName
         
         // ball の座標を決定
         let ballPosition:SIMD3<Float> = SIMD3(radius * sin(radians),radius * cos(radians),0)
         ball.setPosition(ballPosition, relativeTo: nil)
         
         ball.components.set(InputTargetComponent(allowedInputTypes: .indirect))
         
         ball.components.set(PhysicsBodyComponent(shapes: [ShapeResource.generateSphere(radius: 0.05)], mass: 0.0, material: material, mode: .kinematic))
         
         if (color == .white) {
         ball.setScale(SIMD3<Float>(0.9,0.9,0.9), relativeTo: nil)
         } else {
         ball.setScale(SIMD3<Float>(1.0,1.0,1.0), relativeTo: nil)
         }
         
         ball.setScale(SIMD3<Float>(1.0,1.0,1.0), relativeTo: nil)
         */
        
        // added by nagao 3/22
        let words = color.accessibilityName.split(separator: " ")
        if let name = words.last, let entity = sceneEntity?.findEntity(named: String(name)) {
            let position: SIMD3<Float> = SIMD3(radius * sin(radians), radius * cos(radians), 0)
            //print("💥 Created color: \(color.accessibilityName), position: \(position)")
            entity.setPosition(position, relativeTo: nil)
            colorPalletEntity.addChild(entity)
        }
    }
    
    // modified by nagao 3/28
    func colorPalletEntityEnabled() {
        if isSoundEnabled && !colorPalletEntity.isEnabled {
            player?.play()
        }

        colorPalletEntity.isEnabled = true
    }
    
    // modified by nagao 3/30 スレッドセーフ化のために修正
    func colorPalletEntityDisable() {
        if (colorPalletEntity.isEnabled) {
            Task {
                DispatchQueue.main.async {
                    self.colorPalletEntity.isEnabled = false
                }
            }
        }
    }
    
    // added by nagao 3/28
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッションの設定に失敗しました: \(error)")
        }
    }

    // added by nagao 3/28
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
}
