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
    
    var player2: AVAudioPlayer?
    var isSoundEnabled2: Bool = false
    
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
        isSoundEnabled2 = loadSound2()
    }
    
    // modified by nagao 3/22
    func setActiveColor(color: SimpleMaterial.Color) {
        activeColor = color
    }
    
    // modified by nagao 2025/6/16
    func updatePosition(position: SIMD3<Float>, wristPosition: SIMD3<Float>) {
        // 1) 手から手首への水平ベクトル
        let toWrist = normalize(simd_make_float3(
            wristPosition.x - position.x,
            0,
            wristPosition.z - position.z
        ))
        
        // 2) ワールド前方向ベクトル (RealityKit ではカメラ前方が -z)
        let worldForward = normalize(simd_float3(0, 0, -1))
        
        // 3) 符号付きヨー角 (rad)：右手系で y 軸回り
        let yaw = atan2(
            simd_dot(toWrist, simd_float3(1,0,0)),      // x 成分
            simd_dot(toWrist, worldForward)             // z 成分
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
    
    // added by nagao 2025/6/28
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
