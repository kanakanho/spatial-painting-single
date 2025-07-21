//
//  ImmersiveView.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import SwiftUI
import ARKit
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    @Environment(ViewModel.self) var model
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State var lastIndexPose: SIMD3<Float>?
    @State var lastTmpStrokeIndexPose: SIMD3<Float>?
    @State var prevLastIndexPose: SIMD3<Float>?
    
    // added by nagao 2025/7/10
    @State private var sourceTransform: Transform?

    @State private var isFileManagerActive: Bool = false

    // added by nagao 2025/6/15
    @Environment(AppModel.self) var appModel
    
    @State var headLockedEntity: Entity = {
        let headAnchor = AnchorEntity(.head)
        headAnchor.position = [0.0, 0.0, -0.1]
        return headAnchor
    }()
    
    @Environment(\.displayScale) private var displayScale: CGFloat
    
    var body: some View {
        RealityView { content in
            do {
                let scene = try await Entity(named: "colorpallet", in: realityKitContentBundle)
                //content.add(scene)
                model.colorPalletModel.setSceneEntity(scene: scene)
                
                content.add(model.setupContentEntity())
                content.add(model.colorPalletModel.colorPalletEntity)
                let root = model.canvas.root
                content.add(root)
                
                // added by nagao 2025/6/16
                model.setAppModel(appModel)
                
                if let eraserEntity = scene.findEntity(named: "collider") {
                    model.canvas.setEraserEntity(eraserEntity)
                } else {
                    print("eraserEntity not found")
                }
                
                if let buttonEntity = scene.findEntity(named: "button") {
                    model.setButtonEntity(buttonEntity)
                } else {
                    print("buttonEntity not found")
                }
                
                if let buttonEntity2 = scene.findEntity(named: "button2") {
                    model.setButtonEntity2(buttonEntity2)
                } else {
                    print("buttonEntity2 not found")
                }
                
                /*
                // added by nagao 3/22
                for fingerEntity in model.fingerEntities.values {
                    //print("Collision Setting for \(fingerEntity.name)")
                    _ = content.subscribe(to: CollisionEvents.Began.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames.contains(collisionEvent.entityB.name) {
                            model.changeFingerColor(entity: fingerEntity, colorName: collisionEvent.entityB.name)
                            model.isEraserMode = false
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) began")
                        } else if collisionEvent.entityB.name == "clear" {
                            let material = SimpleMaterial(color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 0.2), isMetallic: true)
                            fingerEntity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                            model.isEraserMode = true
                            _ = model.recordTime(isBegan: true)
                        } else if collisionEvent.entityB.components.contains(where: {$0 is StrokeComponent}) {
                            if !model.isEraserMode || !model.canvas.tmpStrokes.isEmpty {
                                return
                            }
                            guard let strokeComponent = collisionEvent.entityB.components[StrokeComponent.self] else {
                                return
                            }
                            model.canvas.root.children.removeAll{ $0.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                            model.canvas.strokes.removeAll{ $0.entity.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                            //print("delete stroke")
                        } else if collisionEvent.entityB.name == "button" {
                            _ = model.recordTime(isBegan: true)
                        } else if collisionEvent.entityB.name == "button2" {
                            _ = model.recordTime(isBegan: true)
                        }
                    }
                    
                    _ = content.subscribe(to: CollisionEvents.Ended.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames.contains(collisionEvent.entityB.name) {
                            model.selectColor(colorName: collisionEvent.entityB.name)
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) ended")
                        } else if collisionEvent.entityB.name == "clear" {
                            if model.recordTime(isBegan: false) {
                                /*
                                 for stroke in model.canvas.strokes {
                                 stroke.entity.removeFromParent()
                                 }
                                 */
                                model.canvas.reset()
                            }
                        } else if collisionEvent.entityB.name == "button" {
                            if model.recordTime(isBegan: false) {
                                model.saveStrokes(displayScale: displayScale)
                            }
                        } else if collisionEvent.entityB.name == "button2" {
                            if model.recordTime(isBegan: false) {
                                if !isFileManagerActive {
                                    DispatchQueue.main.async {
                                        openWindow(id: "ExternalStroke")
                                    }
                                } else {
                                    model.confirmTmpStrokes()
                                    DispatchQueue.main.async {
                                        dismissWindow(id: "ExternalStroke")
                                    }
                                }
                                isFileManagerActive.toggle()
                            }
                        }
                    }
                }

                // modified by nagao 2025/7/17
                for fingerEntity in model.fingerEntities.values {
                    //print("Collision Setting for \(fingerEntity.name)")
                    _ = content.subscribe(to: CollisionEvents.Began.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames().contains(collisionEvent.entityB.name) {
                            //print("Finger touched to: \(collisionEvent.entityB.name)")
                            model.changeFingerColor(entity: fingerEntity, colorName: collisionEvent.entityB.name)
                            model.isEraserMode = false
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) began")
                        } else if model.colorPalletModel.toolNames().contains(collisionEvent.entityB.name) {
                            model.changeFingerLineWidth(entity: fingerEntity, toolName: collisionEvent.entityB.name)
                            model.isEraserMode = false
                        } else if collisionEvent.entityB.name == "eraser" {
                            let material = SimpleMaterial(color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 0.2), isMetallic: true)
                            fingerEntity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                            model.resetColor()
                            model.isEraserMode = true
                            model.colorPalletModel.selectedToolName = "eraser"
                            _ = model.recordTime(isBegan: true)
                        } else if collisionEvent.entityB.components.contains(where: {$0 is StrokeComponent}) {
                            if !model.isEraserMode || !model.canvas.tmpStrokes.isEmpty {
                                return
                            }
                            guard let strokeComponent = collisionEvent.entityB.components[StrokeComponent.self] else {
                                return
                            }
                            model.canvas.root.children.removeAll{ $0.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                            model.canvas.strokes.removeAll{ $0.entity.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                            //print("delete stroke")
                        } else if collisionEvent.entityB.name == "button" {
                            _ = model.recordTime(isBegan: true)
                        } else if collisionEvent.entityB.name == "button2" {
                            _ = model.recordTime(isBegan: true)
                        }
                    }
                    
                    _ = content.subscribe(to: CollisionEvents.Ended.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames().contains(collisionEvent.entityB.name) {
                            model.selectColor(colorName: collisionEvent.entityB.name)
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) ended")
                        } else if model.colorPalletModel.toolNames().contains(collisionEvent.entityB.name) {
                            model.selectLineWidth(toolName: collisionEvent.entityB.name)
                        } else if collisionEvent.entityB.name == "eraser" {
                            if model.recordTime(isBegan: false) {
                                model.canvas.reset()
                            }
                        } else if collisionEvent.entityB.name == "button" {
                            if model.recordTime(isBegan: false) {
                                model.saveStrokes(displayScale: displayScale)
                            }
                        } else if collisionEvent.entityB.name == "button2" {
                            if model.recordTime(isBegan: false) {
                                if !isFileManagerActive {
                                    DispatchQueue.main.async {
                                        openWindow(id: "ExternalStroke")
                                    }
                                } else {
                                    model.confirmTmpStrokes()
                                    DispatchQueue.main.async {
                                        dismissWindow(id: "ExternalStroke")
                                    }
                                }
                                isFileManagerActive.toggle()
                            }
                        }
                    }
                }
                */

                // added by nagao 2015/7/19
                setupCollisionSubscriptions(on: content)

                root.components.set(ClosureComponent(closure: { deltaTime in
                    var anchors = [HandAnchor]()
                    
                    if let left = model.latestHandTracking.left {
                        anchors.append(left)
                    }
                    
                    if let right = model.latestHandTracking.right {
                        anchors.append(right)
                    }
                    
                    // Loop through each anchor the app detects.
                    for anchor in anchors {
                        /// The hand skeleton that associates the anchor.
                        guard let handSkeleton = anchor.handSkeleton else {
                            continue
                        }
                        
                        /// The current position and orientation of the thumb tip.
                        let thumbPos = (
                            anchor.originFromAnchorTransform * handSkeleton.joint(.thumbTip).anchorFromJointTransform).translation()
                        
                        /// The current position and orientation of the index finger tip.
                        let indexPos = (anchor.originFromAnchorTransform * handSkeleton.joint(.indexFingerTip).anchorFromJointTransform).translation()
                        
                        /// The threshold to check if the index and thumb are close.
                        let pinchThreshold: Float = 0.03
                        
                        // Update the last index position if the distance
                        // between the thumb tip and index finger tip is
                        // less than the pinch threshold.
                        if length(thumbPos - indexPos) < pinchThreshold {
                            lastIndexPose = indexPos
                        }
                    }
                }))
            } catch {
                print("Error in RealityView's make: \(error)")
            }
        }
        .task {
            //model.webSocketClient.connect()
            do {
                /*
                 if model.dataProvidersAreSupported && model.isReadyToRun {
                 try await model.session.run([model.sceneReconstruction, model.handTracking])
                 } else {
                 await dismissImmersiveSpace()
                 }
                 */
                try await model.session.run([model.sceneReconstruction, model.handTracking])
            } catch {
                print("Failed to start session: \(error)")
                await dismissImmersiveSpace()
                openWindow(id: "error")
            }
        }
        .task {
            await model.processHandUpdates()
        }
        .task(priority: .low) {
            await model.processReconstructionUpdates()
        }
        .task {
            await model.monitorSessionEvents()
        }
        .task {
            await model.processWorldUpdates()
        }
        .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                //model.initBall()
                model.colorPalletModel.initEntity()
            }
        }
        .onChange(of: appModel.isArrowShown) { _, newValue in
            Task {
                if newValue {
                    model.showHandArrowEntities()
                } else {
                    model.hideHandArrowEntities()
                }
            }
        }
        .onDisappear {
            model.dismissHandArrowEntities()
            model.colorPalletModel.colorPalletEntity.children.removeAll()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .simultaneously(with: MagnifyGesture())
                .targetedToAnyEntity()
                .onChanged({ value in
                    if sourceTransform == nil {
                        sourceTransform = value.entity.transform
                    }
                    // added by nagao 2025/7/10
                    if !model.canvas.tmpStrokes.isEmpty {
                        if value.entity.name == "boundingBox" {
                            let isHandGripped = self.model.isHandGripped

                            if isHandGripped {
                                if let translation = value.first?.translation3D {
                                    let rotationX = Float(translation.x / 1000.0) * .pi
                                    let rotationY = Float(translation.y / 1000.0) * .pi
                                    
                                    //print("rotationX = \(rotationX), rotationY = \(rotationY)")
                                    value.entity.transform.rotation = sourceTransform!.rotation * simd_quatf(angle: rotationX, axis: [0, 1, 0]) * simd_quatf(angle: rotationY, axis: [1, 0, 0])
                                }
                            } else if let magnification = value.second?.magnification {
                                //print("magnification: \(magnification)")
                                let magnification = Float(magnification)

                                value.entity.transform.scale = [sourceTransform!.scale.x * magnification, sourceTransform!.scale.y * magnification, sourceTransform!.scale.z * magnification]
                                
                                value.entity.children.forEach { child in
                                    model.canvas.tmpStrokes.filter({ $0.entity.components[StrokeComponent.self]?.uuid == child.components[StrokeComponent.self]?.uuid }).forEach { stroke in
                                        stroke.updateMaxRadiusAndRemesh(scaleFactor: value.entity.transform.scale.sum() / 3)
                                    }
                                }
                                
                            } else if let translation = value.first?.translation3D {
                                let convertedTranslation = value.convert(translation, from: .local, to: value.entity.parent!)

                                value.entity.transform.translation = sourceTransform!.translation + convertedTranslation
                            }
                        }
                    } else if !model.isEraserMode, let pos = lastIndexPose {
                        let uuid: UUID = UUID()
                        model.canvas.addPoint(uuid, pos)
                    }
                })
                .onEnded({ _ in
                    if model.canvas.tmpStrokes.isEmpty, !model.isEraserMode {
                        model.canvas.finishStroke()
                    }

                    sourceTransform = nil
                })
        )
    }
    
    static func rotateEntityAroundXAxis(entity: Entity, angle: Float) {
        // Get the current transform of the entity
        var currentTransform = entity.transform
        
        // Create a quaternion representing a rotation around the Y-axis
        let rotation = simd_quatf(angle: angle, axis: [1, 0, 0])
        
        // Combine the rotation with the current transform
        currentTransform.rotation = rotation * currentTransform.rotation
        
        // Apply the new transform to the entity
        entity.transform = currentTransform
    }
}

// added by nagao 2015/7/19
extension ImmersiveView {
    func setupCollisionSubscriptions(on content: RealityViewContent) {
        for finger in model.fingerEntities.values {
            subscribeBegan(on: finger, content: content)
            subscribeEnded(on: finger, content: content)
        }
    }
    
    private func subscribeBegan(on entity: Entity, content: RealityViewContent) {
        _ = content.subscribe(to: CollisionEvents.Began.self, on: entity) { (event: CollisionEvents.Began) in
            handleBegan(event: event, finger: entity)
        }
    }
    
    private func handleBegan(event: CollisionEvents.Began, finger: Entity) {
        let name = event.entityB.name
        
        if model.colorPalletModel.colorNames().contains(name) {
            didTouchColor(name, finger: finger)
        }
        else if model.colorPalletModel.toolNames().contains(name) {
            didTouchTool(name, finger: finger)
        }
        else if name == "eraser" {
            activateEraser(finger: finger)
        }
        else if event.entityB.hasStrokeComponent, model.isEraserMode, model.canvas.tmpStrokes.isEmpty {
            deleteStroke(event.entityB)
        }
        else if name == "button" || name == "button2" {
            _ = model.recordTime(isBegan: true)
        }
    }
    
    private func subscribeEnded(on entity: Entity, content: RealityViewContent) {
        _ = content.subscribe(to: CollisionEvents.Ended.self, on: entity) { (event: CollisionEvents.Ended) in
            handleEnded(event: event, finger: entity)
        }
    }
    
    private func handleEnded(event: CollisionEvents.Ended, finger: Entity) {
        let name = event.entityB.name
        
        if model.colorPalletModel.colorNames().contains(name) {
            model.selectColor(colorName: name)
        }
        else if model.colorPalletModel.toolNames().contains(name) {
            model.selectLineWidth(toolName: name)
        }
        else if name == "eraser" {
            if model.recordTime(isBegan: false) {
                model.canvas.reset()
            }
        }
        else if name == "button" {
            if model.recordTime(isBegan: false) {
                model.saveStrokes(displayScale: displayScale)
            }
        }
        else if name == "button2" {
            if model.recordTime(isBegan: false) {
                toggleExternalStrokeWindow()
            }
        }
    }
    
    // MARK: — Began-handlers
    private func didTouchColor(_ name: String, finger: Entity) {
        model.changeFingerColor(entity: finger, colorName: name)
        model.isEraserMode = false
    }

    private func didTouchTool(_ name: String, finger: Entity) {
        model.changeFingerLineWidth(entity: finger, toolName: name)
        model.isEraserMode = false
    }

    private func activateEraser(finger: Entity) {
        let eraserMat = SimpleMaterial(
            color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 0.2),
            isMetallic: true
        )
        finger.components.set(
            ModelComponent(
                mesh: .generateSphere(radius: 0.01),
                materials: [eraserMat]
            )
        )
        model.resetColor()
        model.isEraserMode = true
        model.colorPalletModel.selectedToolName = "eraser"
        _ = model.recordTime(isBegan: true)
    }

    private func deleteStroke(_ entity: Entity) {
        guard let comp = entity.components[StrokeComponent.self] else { return }
        // シーンとモデル両方から削除
        model.canvas.root.children.removeAll {
            $0.components[StrokeComponent.self]?.uuid == comp.uuid
        }
        model.canvas.strokes.removeAll {
            $0.entity.components[StrokeComponent.self]?.uuid == comp.uuid
        }
    }

    // MARK: — Ended-handlers
    private func toggleExternalStrokeWindow() {
        if !isFileManagerActive {
            openWindow(id: "ExternalStroke")
        } else {
            model.confirmTmpStrokes()
            dismissWindow(id: "ExternalStroke")
        }
        isFileManagerActive.toggle()
    }
}

// MARK: — Entity 拡張
private extension Entity {
    /// StrokeComponent を持っているかどうか
    var hasStrokeComponent: Bool {
        components.contains { $0 is StrokeComponent }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
