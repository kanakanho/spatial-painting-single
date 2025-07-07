//
//  ViewModel.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import ARKit
import RealityKit
import SwiftUI

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

@Observable
@MainActor
class ViewModel {
    let webSocketClient: WebSocketClient = .init()
    let colorPalletModel = ColorPalletModel()
    var canvas = PaintingCanvas()
    
    var externalStrokeFileWapper: ExternalStrokeFileWapper = ExternalStrokeFileWapper()
    
    let session = ARKitSession()
    let handTracking = HandTrackingProvider()
    let sceneReconstruction = SceneReconstructionProvider()
    let worldTracking = WorldTrackingProvider()
    
    private var meshEntities = [UUID: ModelEntity]()
    var contentEntity = Entity()
    var latestHandTracking: HandsUpdates = .init(left: nil, right: nil)
    var leftHandEntity = Entity()
    var rightHandEntity = Entity()
    
    var latestWorldTracking: WorldAnchor = .init(originFromAnchorTransform: .init())
    
    var isGlab: Bool = false
    
    enum OperationLock {
        case none
        case right
        case left
    }
    
    enum HandGlab {
        case right
        case left
    }
    
    var entitiyOperationLock = OperationLock.none
    
    // ここで反発係数を決定している可能性あり
    let material = PhysicsMaterialResource.generate(friction: 0.8,restitution: 0.0)
    
    struct HandsUpdates {
        var left: HandAnchor?
        var right: HandAnchor?
    }
    
    var errorState = false
    
    // ストロークを消去する時の長押し時間 added by nagao 2025/3/24
    var clearTime: Int = 0
    
    // ストロークを選択的に消去するモード added by nagao 2025/6/20
    var isEraserMode: Bool = false
    
    // added by nagao 2025/6/15
    var handSphereEntity: Entity? = nil
    
    var handArrowEntities: [Entity] = []
    
    var buttonEntity: Entity = Entity()
    
    var axisVectors: [SIMD3<Float>] = [SIMD3<Float>(0,0,0), SIMD3<Float>(0,0,0), SIMD3<Float>(0,0,0)]
    
    var normalVector: SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    var planeNormalVector: SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    var planePoint: SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    var appModel: AppModel?
    
    func setAppModel(_ model: AppModel) {
        self.appModel = model
    }
    
    func setButtonEntity(_ entity: Entity) {
        self.buttonEntity = entity
    }
    
    func showHandArrowEntities() {
        if handSphereEntity != nil {
            contentEntity.addChild(handSphereEntity!)
            if handArrowEntities.count > 0 {
                for entity in handArrowEntities {
                    contentEntity.addChild(entity)
                }
            }
        }
    }
    
    func hideHandArrowEntities() {
        if handSphereEntity != nil {
            handSphereEntity!.removeFromParent()
            if handArrowEntities.count > 0 {
                for entity in handArrowEntities {
                    entity.removeFromParent()
                }
            }
        }
    }
    
    func dismissHandArrowEntities() {
        if handSphereEntity != nil {
            handSphereEntity!.removeFromParent()
            if handArrowEntities.count > 0 {
                for entity in handArrowEntities {
                    entity.removeFromParent()
                }
                handArrowEntities = []
            }
        }
        handSphereEntity = nil
        colorPalletModel.colorPalletEntityDisable()
        
        buttonEntity.removeFromParent()
    }
    
    let fingerEntities: [HandAnchor.Chirality: ModelEntity] = [/*.left: .createFingertip(name: "L", color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)),*/ .right: .createFingertip(name: "R", color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0))]
    
    func setupContentEntity() -> Entity {
        for entity in fingerEntities.values {
            contentEntity.addChild(entity)
        }
        return contentEntity
    }
    
    // 指先に球を表示 added by nagao 2025/3/22
    func showFingerTipSpheres() {
        for entity in fingerEntities.values {
            contentEntity.addChild(entity)
        }
    }
    
    func dismissFingerTipSpheres() {
        for entity in fingerEntities.values {
            entity.removeFromParent()
        }
    }
    
    func changeFingerColor(entity: Entity, colorName: String) {
        for color in colorPalletModel.colors {
            let words = color.accessibilityName.split(separator: " ")
            if let name = words.last, name == colorName {
                let material = SimpleMaterial(color: color, isMetallic: true)
                entity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                break
            }
        }
    }
    
    var dataProvidersAreSupported: Bool {
        HandTrackingProvider.isSupported && SceneReconstructionProvider.isSupported
    }
    
    var isReadyToRun: Bool {
        handTracking.state == .initialized && sceneReconstruction.state == .initialized
    }
    
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor
            
            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            switch update.event {
            case .added:
                let entity = ModelEntity()
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                entity.components.set(InputTargetComponent())
                
                // mode が dynamic でないと物理演算が適用されない
                entity.physicsBody = PhysicsBodyComponent(mode: .dynamic)
                
                meshEntities[meshAnchor.id] = entity
                contentEntity.addChild(entity)
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else { continue }
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision?.shapes = [shape]
            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
    }
    
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(type: _, status: let status):
                print("Authorization changed to: \(status)")
                
                if status == .denied {
                    errorState = true
                }
            case .dataProviderStateChanged(dataProviders: let providers, newState: let state, error: let error):
                print("Data provider changed: \(providers), \(state)")
                if let error {
                    print("Data provider reached an error state: \(error)")
                    errorState = true
                }
            @unknown default:
                fatalError("Unhandled new event type \(event)")
            }
        }
    }
    
    func processWorldUpdates() async {
        for await update in worldTracking.anchorUpdates {
            switch update.event {
            case .updated:
                let anchor = update.anchor
                latestWorldTracking = anchor
                print(latestWorldTracking.originFromAnchorTransform.position)
            default:
                break
            }
        }
    }
    
    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .updated:
                let anchor = update.anchor
                
                guard anchor.isTracked else { continue }
                
                // added by nagao 2025/3/22
                let fingerTipIndex = anchor.handSkeleton?.joint(.indexFingerTip)
                let originFromWrist = anchor.originFromAnchorTransform
                let wristFromIndex = fingerTipIndex?.anchorFromJointTransform
                let originFromIndex = originFromWrist * wristFromIndex!
                fingerEntities[anchor.chirality]?.setTransformMatrix(originFromIndex, relativeTo: nil)
                
                if anchor.chirality == .left {
                    latestHandTracking.left = anchor
                    guard let handAnchor = latestHandTracking.left else { continue }
                    // glabGesture(handAnchor: handAnchor,handGlab: .left)
                    watchLeftPalm(handAnchor: handAnchor)
                    webSocketClient.sendHandAnchor(handAnchor)
                } else if anchor.chirality == .right {
                    latestHandTracking.right = anchor
                    // guard let handAnchor = latestHandTracking.right else { continue }
                    // glabGesture(handAnchor: handAnchor,handGlab: .right)
                    // tapColorBall(handAnchor: handAnchor)
                }
            default:
                break
            }
        }
    }
    
    // ボールの初期化
    func initBall() {
        guard let originTransform = latestHandTracking.right?.originFromAnchorTransform else { return }
        guard let handSkeletonAnchorTransform =  latestHandTracking.right?.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else { return }
        
        let originFromIndex = originTransform * handSkeletonAnchorTransform
        let place = originFromIndex.columns.3.xyz
        
        let ball = ModelEntity(
            mesh: .generateSphere(radius: 0.02),
            materials: [SimpleMaterial(color: .white, isMetallic: true)],
            collisionShape: .generateSphere(radius: 0.05),
            mass: 1.0
        )
        
        ball.name = "ball"
        ball.setPosition(place, relativeTo: nil)
        ball.components.set(InputTargetComponent(allowedInputTypes: .all))
        
        // mode が dynamic でないと物理演算が適用されない
        ball.components.set(PhysicsBodyComponent(shapes: [ShapeResource.generateSphere(radius: 0.05)], mass: 1.0, material: material, mode: .static))
        
        contentEntity.addChild(ball)
    }
    
    // 握るジェスチャーの検出
    func glabGesture(handAnchor: HandAnchor, handGlab: HandGlab) {
        if(handGlab == .right && entitiyOperationLock == .left || handGlab == .left && entitiyOperationLock == .right) {
            return
        }
        
        guard let wrist = handAnchor.handSkeleton?.joint(.wrist).anchorFromJointTransform else { return }
        guard let thumbIntermediateTip = handAnchor.handSkeleton?.joint(.thumbIntermediateTip).anchorFromJointTransform else { return }
        guard let indexFingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else { return }
        guard let middleFingerTip = handAnchor.handSkeleton?.joint(.middleFingerTip).anchorFromJointTransform else { return }
        guard let ringFingerTip = handAnchor.handSkeleton?.joint(.ringFingerTip).anchorFromJointTransform else { return }
        guard let littleFingerTip = handAnchor.handSkeleton?.joint(.littleFingerTip).anchorFromJointTransform else { return }
        
        let thumbIntermediateTipToWristDistance = simd_length_squared(wrist.columns.3.xyz - thumbIntermediateTip.columns.3.xyz)
        let indexFingerTipToWristDistance = simd_length_squared(wrist.columns.3.xyz - indexFingerTip.columns.3.xyz)
        let middleFingerTipToWristDistance = simd_length_squared(wrist.columns.3.xyz - middleFingerTip.columns.3.xyz)
        let ringFingerTipToWristDistance = simd_length_squared(wrist.columns.3.xyz - ringFingerTip.columns.3.xyz)
        let littleFingerTipToWristDistance = simd_length_squared(wrist.columns.3.xyz - littleFingerTip.columns.3.xyz)
        
        // ボールエンティティの取得
        guard let ballEntity = contentEntity.children.first(where: { $0.name == "ball" }) as? ModelEntity else { return }
        
        // ボールとの距離を計算
        let ballPositionTransformMatrix = contentEntity.transform.matrix * ballEntity.transform.matrix
        let handPositionTransformMatrix = handAnchor.originFromAnchorTransform * indexFingerTip
        let ballHandLength = simd_length_squared(ballPositionTransformMatrix.columns.3.xyz - handPositionTransformMatrix.columns.3.xyz)
        
        // ボールとの距離で判定
        if  ballHandLength > 0.20 {
            isGlab = false
            return
        }
        
        // 手の形を判定
        if thumbIntermediateTipToWristDistance > 0.01
            && indexFingerTipToWristDistance > 0.01
            && middleFingerTipToWristDistance > 0.01
            && ringFingerTipToWristDistance > 0.01
            && littleFingerTipToWristDistance > 0.01 {
            print(Date().timeIntervalSince1970,"\tにぎらない")
            // 物理演算を再開
            ballEntity.components.set((PhysicsBodyComponent(shapes: [ShapeResource.generateSphere(radius: 0.05)], mass: 1.0, material: material, mode: .dynamic)))
            isGlab = false
            entitiyOperationLock = .none
            return
        }
        
        print(Date().timeIntervalSince1970,"\tにぎる")
        
        // 握っている間は物理演算を解除
        ballEntity.components.set((PhysicsBodyComponent(shapes: [ShapeResource.generateSphere(radius: 0.05)], mass: 1.0, material: material, mode: .static)))
        
        ballEntity.transform = Transform(
            matrix: matrix_multiply(handAnchor.originFromAnchorTransform, (handAnchor.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform)!)
        )
        
        isGlab = true
        
        // 手の向きに力を加える
        ballEntity.addForce(calculateForceDirection(handAnchor: handAnchor) * 4, relativeTo: nil)
        entitiyOperationLock = handGlab == .right ? .right : .left
    }
    
    func simd_distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return simd_length(a - b)
    }
    
    // 手の向きに基づいて力を加える方向を計算
    func calculateForceDirection(handAnchor: HandAnchor) -> SIMD3<Float> {
        let handRotation = Transform(matrix: handAnchor.originFromAnchorTransform).rotation
        return handRotation.act(handAnchor.chirality == .left ? SIMD3(1, 0, 0) : SIMD3(-1, 0, 0))
    }
    
    // 左の掌の向きを計算
    func watchLeftPalm(handAnchor: HandAnchor) {
        guard let senseThreshold = appModel?.senseThreshold,
              let distanceThreshold = appModel?.distanceThreshold,
              let isArrowShown = appModel?.isArrowShown else { return }
        
        guard let middleBase = handAnchor.handSkeleton?.joint(.middleFingerTip),
              let littleBase = handAnchor.handSkeleton?.joint(.littleFingerTip),
              let thumbBase = handAnchor.handSkeleton?.joint(.thumbTip),
              let middleFingerIntermediateBase = handAnchor.handSkeleton?.joint(.middleFingerIntermediateBase),
              let middleFingerKnuckleBase = handAnchor.handSkeleton?.joint(.middleFingerKnuckle),
              let wristBase = handAnchor.handSkeleton?.joint(.wrist)
        else { return }
        
        guard let rightHandAnchor = latestHandTracking.right,
              let rightWristBase = rightHandAnchor.handSkeleton?.joint(.wrist)
        else { return }
        
        let button = buttonEntity
        
        let middle: simd_float4x4 = handAnchor.originFromAnchorTransform * middleBase.anchorFromJointTransform
        let little: simd_float4x4 = handAnchor.originFromAnchorTransform * littleBase.anchorFromJointTransform
        let wrist: simd_float4x4 = handAnchor.originFromAnchorTransform * wristBase.anchorFromJointTransform
        let thumb: simd_float4x4 = handAnchor.originFromAnchorTransform * thumbBase.anchorFromJointTransform
        let positionMatrix: simd_float4x4 = handAnchor.originFromAnchorTransform * middleFingerIntermediateBase.anchorFromJointTransform
        let middleKnuckle: simd_float4x4 = handAnchor.originFromAnchorTransform * middleFingerKnuckleBase.anchorFromJointTransform
        
        let wristPos = simd_make_float3(wrist.columns.3)
        let middlePos = simd_make_float3(middle.columns.3)
        let littlePos = simd_make_float3(little.columns.3)
        let thumbPos = simd_make_float3(thumb.columns.3)
        let middleKnucklePos = simd_make_float3(middleKnuckle.columns.3)
        
        let distances = [
            distance(middlePos, thumbPos),
            distance(middlePos, littlePos),
            distance(middlePos, wristPos)
        ]
        
        //print("hand joints distance \(distances)")
        let handSize = max(distance(wristPos, middleKnucklePos), 0.1) // 手のサイズの最大値を取得
        //print("hand size \(handSize)")
        let threshold = handSize * 0.5 // 手のサイズに基づいた閾値を計算
        let flag = distances.allSatisfy { $0 > threshold }
        
        if !flag {
            if isArrowShown && handSphereEntity != nil {
                handSphereEntity!.removeFromParent()
                if handArrowEntities.count > 0 {
                    for entity in handArrowEntities {
                        entity.removeFromParent()
                    }
                    handArrowEntities = []
                }
            }
            handSphereEntity = nil
            colorPalletModel.colorPalletEntityDisable()
            return
        } else {
            if handSphereEntity == nil {
                createHandSphere(wrist: wristPos, middle: middlePos, little: littlePos, isArrowShown: isArrowShown)
            } else {
                updateHandSphere(wrist: wristPos, middle: middlePos, little: littlePos)
            }
        }
        
        // ワールドの上方向ベクトル
        let worldUp = simd_float3(0, 1, 0)
        let dot = simd_dot(normalVector, worldUp)
        if dot > senseThreshold {
            button.setPosition(calculateExtendedPoint(point: planePoint, vector: normalVector, distance: 0.07), relativeTo: nil)
            contentEntity.addChild(button)
        } else {
            button.removeFromParent()
        }
        
        // ワールドの下方向ベクトル
        let worldDown = simd_float3(0, -1, 0)
        let dot2 = simd_dot(normalVector, worldDown)
        //print("💥 法線ベクトルとの内積 \(dot)")
        //let distance = distance(positionMatrix.position, head.position) / 2.0
        //print("💥 頭との距離 \(distance)")
        
        let rightWrist: simd_float4x4 = rightHandAnchor.originFromAnchorTransform * rightWristBase.anchorFromJointTransform
        let rightWristPos = simd_make_float3(rightWrist.columns.3)
        let distance = distance(positionMatrix.position, rightWristPos)
        //print("💥 右手との距離 \(distance)")
        
        let isShow = dot2 > senseThreshold && distance < distanceThreshold
        
        if (!isShow/*positionMatrix.codable[1][1] < positionMatrix.codable[2][2]*/) {
            colorPalletModel.colorPalletEntityDisable()
            return
        }
        
        //colorPalletModel.colorPalletEntityEnabled()
        if !(colorPalletModel.colorPalletEntity.isEnabled) {
            colorPalletModel.colorPalletEntityEnabled()
        }
        
        /*
         guard let rightOriginAnchor = latestHandTracking.right?.originFromAnchorTransform else {return}
         guard let rightIndexFingerTipAnchor =  latestHandTracking.right?.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else {return}
         let rightIndexFingerTip = rightOriginAnchor * rightIndexFingerTipAnchor
         
         // ball の位置を wrist にする
         contentEntity.findEntity(named: "ball")?.setPosition(rightIndexFingerTip.position, relativeTo: nil)
         */
        
        // added by nagao 3/22
        colorPalletModel.updatePosition(position: positionMatrix.position, wristPosition: wristPos)
    }
    
    func createHandSphere(wrist: SIMD3<Float>, middle: SIMD3<Float>, little: SIMD3<Float>, isArrowShown: Bool) {
        // 中指と手首を結ぶベクトル
        let axisVector = simd_float3(x: middle.x - wrist.x, y: middle.y - wrist.y, z: middle.z - wrist.z)
        
        axisVectors[0] = simd_normalize(axisVector)
        
        // 線分ABから点Cへの垂線ベクトルを計算
        let perpendicularVector = perpendicularVectorFromPointToSegment(A: wrist, B: middle, C: little)
        
        axisVectors[1] = simd_normalize(perpendicularVector)
        
        axisVectors[2] = simd_cross(axisVectors[0], axisVectors[1])
        
        let sphereEntity = ModelEntity(mesh: .generateSphere(radius: 0.02), materials: [SimpleMaterial(color: .systemRed, isMetallic: false)], collisionShape: .generateSphere(radius: 0.02), mass: 0.0)
        
        let center = (wrist + middle) / 2.0
        
        sphereEntity.position = center
        
        if isArrowShown {
            contentEntity.addChild(sphereEntity)
        }
        
        handSphereEntity = sphereEntity
        
        normalVector = axisVectors[2]
        
        planeNormalVector = axisVectors[0]
        
        planePoint = center
        
        for vector in axisVectors {
            let arrowEntity = Entity()
            
            // 矢印の円柱（軸部分）を作成
            let arrowLength: Float = 0.15
            let direction = vector
            let cylinderMesh = MeshResource.generateCylinder(height: arrowLength * 0.8, radius: 0.01)
            let material = SimpleMaterial(color: .green, isMetallic: false)
            let cylinderEntity = ModelEntity(mesh: cylinderMesh, materials: [material])
            
            // 回転軸に沿った回転を適用
            let axisDirection = normalize(direction)
            let quaternion = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: axisDirection)
            cylinderEntity.orientation = quaternion
            
            // 位置を設定（矢印の中央が開始位置になるように調整）
            cylinderEntity.position = direction * arrowLength * 0.4
            arrowEntity.addChild(cylinderEntity)
            
            // 矢尻（円錐部分）を作成
            let coneMesh = MeshResource.generateCone(height: arrowLength * 0.2, radius: 0.02)
            let coneMaterial = SimpleMaterial(color: .red, isMetallic: false)
            let coneEntity = ModelEntity(mesh: coneMesh, materials: [coneMaterial])
            
            // 矢尻の回転を軸に合わせる
            coneEntity.orientation = quaternion
            
            // 矢尻の位置を調整（矢印の先端に配置）
            coneEntity.position = direction * arrowLength * 0.9
            arrowEntity.addChild(coneEntity)
            
            arrowEntity.position = center
            
            handArrowEntities.append(arrowEntity)
            
            if isArrowShown {
                contentEntity.addChild(arrowEntity)
            }
        }
    }
    
    func updateHandSphere(wrist: SIMD3<Float>, middle: SIMD3<Float>, little: SIMD3<Float>) {
        if handSphereEntity == nil {
            return
        }
        
        // 中指と手首を結ぶベクトル
        let axisVector = simd_float3(x: middle.x - wrist.x, y: middle.y - wrist.y, z: middle.z - wrist.z)
        
        let currentAxisVector = simd_normalize(axisVector)
        
        // 線分ABから点Cへの垂線ベクトルを計算
        let perpendicularVector = perpendicularVectorFromPointToSegment(A: wrist, B: middle, C: little)
        
        let currentLittleVector = simd_normalize(perpendicularVector)
        
        let currentNormalVector = simd_cross(currentAxisVector, currentLittleVector)
        
        let center = (wrist + middle) / 2.0
        
        handSphereEntity!.position = center
        
        normalVector = currentNormalVector
        
        planeNormalVector = currentAxisVector
        
        planePoint = center
        
        let vectors = [currentAxisVector, currentLittleVector, currentNormalVector]
        var quats: [simd_quatf] = []
        for (index, vector) in vectors.enumerated() {
            let arrowEntity = handArrowEntities[index]
            
            arrowEntity.position = center
            
            // クォータニオンを計算
            let quat = calculateQuaternionFromVectors(axisVectors[index], vector)
            quats.append(quat)
            
            // エンティティに回転を適用
            arrowEntity.orientation = quat
        }
    }
    
    // 線分ABからCへの垂線ベクトルを計算する関数
    func perpendicularVectorFromPointToSegment(A: simd_float3, B: simd_float3, C: simd_float3) -> simd_float3 {
        let AB = B - A
        let AC = C - A
        
        // tの計算 (ACをABに射影するためのスカラー)
        let t = simd_dot(AC, AB) / simd_dot(AB, AB)
        
        // 射影点Pを計算
        let projection = A + t * AB
        
        // 点Cから射影点Pへのベクトル (これが垂線ベクトル)
        let perpendicularVector = C - projection
        return perpendicularVector
    }
    
    // 法線ベクトルを計算する関数
    func calculateNormalVector(A: simd_float3, B: simd_float3, C: simd_float3) -> simd_float3 {
        let AB = B - A
        let AC = C - A
        let normal = simd_cross(AB, AC)
        return simd_normalize(normal)
    }
    
    // ベクトルAからベクトルBへの回転を計算する関数
    func calculateQuaternionFromVectors(_ A: simd_float3, _ B: simd_float3) -> simd_quatf {
        // ベクトルAとベクトルBを正規化する
        let normalizedA = simd_normalize(A)
        let normalizedB = simd_normalize(B)
        
        // ベクトルAとBの内積を使ってコサイン角度を計算
        let dotProduct = simd_dot(normalizedA, normalizedB)
        
        // もしベクトルAとBが平行でない場合、回転軸を外積で求める
        let crossProduct = simd_cross(normalizedA, normalizedB)
        
        // 回転角度は内積の逆余弦で計算
        let angle = acos(dotProduct)
        
        // 回転クォータニオンを作成
        if simd_length(crossProduct) > 1e-6 {
            // 有効な回転軸が存在する場合にクォータニオンを作成
            return simd_quatf(angle: angle, axis: simd_normalize(crossProduct))
        } else {
            // AとBが同じ方向を向いている場合、単位クォータニオンを返す
            return simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))  // 回転不要
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
    
    // 色を選択する added by nagao 2025/3/22
    func selectColor(colorName: String) {
        for color in colorPalletModel.colors {
            let words = color.accessibilityName.split(separator: " ")
            if let name = words.last, name == colorName {
                //print("💥 Selected color accessibilityName \(color.accessibilityName)")
                colorPalletModel.colorPalletEntityDisable()
                colorPalletModel.setActiveColor(color: color)
                canvas.setActiveColor(color: color)
                //canvas.currentStroke?.setActiveColor(color: color)
                break
            }
        }
    }
    
    func tapColorBall(handAnchor: HandAnchor) {
        guard let indexFingerTipAnchor = handAnchor.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else {return}
        let indexFingerTipOrigin = handAnchor.originFromAnchorTransform
        let indexFingerTip = indexFingerTipOrigin * indexFingerTipAnchor
        let colorPalletModelMatrix = colorPalletModel.colorPalletEntity.transform
        for color in colorPalletModel.colors {
            guard let colorEntity = colorPalletModel.colorPalletEntity.findEntity(named: color.accessibilityName) else { continue }
            let colorBall = colorPalletModelMatrix.matrix * colorEntity.transform.matrix
            if simd_distance(colorBall.position, indexFingerTip.position) < 0.005 {
                colorPalletModel.colorPalletEntityDisable()
                colorPalletModel.setActiveColor(color: color)
                canvas.currentStroke?.setActiveColor(color: color)
            }
        }
    }
    
    // ストロークを消去する時の長押し時間の処理 added by nagao 2025/3/24
    func recordTime(isBegan: Bool) -> Bool {
        if isBegan {
            let now = Date()
            let milliseconds = Int(now.timeIntervalSince1970 * 1000)
            let calendar = Calendar.current
            let nanoseconds = calendar.component(.nanosecond, from: now)
            let exactMilliseconds = milliseconds + (nanoseconds / 1_000_000)
            clearTime = exactMilliseconds
            //print("現在時刻: \(exactMilliseconds)")
            return true
        } else {
            if clearTime > 0 {
                let now = Date()
                let milliseconds = Int(now.timeIntervalSince1970 * 1000)
                let calendar = Calendar.current
                let nanoseconds = calendar.component(.nanosecond, from: now)
                let exactMilliseconds = milliseconds + (nanoseconds / 1_000_000)
                let time = exactMilliseconds - clearTime
                if time > 1000 {
                    clearTime = 0
                    //print("経過時間: \(time)")
                    return true
                }
            }
            return false
        }
    }
    
    // added by nagao 2025/6/28
    func saveStrokes(displayScale: CGFloat) {
        let externalStrokes: [ExternalStroke] = .init(strokes: canvas.strokes, initPoint: .one)
        externalStrokeFileWapper.planeNormalVector = planeNormalVector
        externalStrokeFileWapper.planePoint = planePoint
        externalStrokeFileWapper.writeStroke(externalStrokes: externalStrokes, displayScale: displayScale)
        colorPalletModel.playShutterSound()
    }
}
